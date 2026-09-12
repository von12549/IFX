using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Access.Abac.Templates;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Access;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Infrastructure.Tests.Authorization;

public class DbAbacPolicyResolverTests
{
    private readonly Mock<IPolicyDefinitionRepository> _repository = new();
    private readonly IAbacTemplateRegistry _registry;
    private readonly StaticAbacPolicyResolver _staticResolver;
    private readonly IMemoryCache _cache;
    private readonly DbAbacPolicyResolver _resolver;

    private static readonly Guid TenantId = Guid.NewGuid();

    public DbAbacPolicyResolverTests()
    {
        _registry = new AbacTemplateRegistry();
        _registry.Register(BuiltInTemplates.SameTenant);
        _registry.Register(BuiltInTemplates.CreatedByMe);

        _staticResolver = new StaticAbacPolicyResolver();

        _cache = new MemoryCache(new MemoryCacheOptions());

        _resolver = new DbAbacPolicyResolver(
            _repository.Object,
            _registry,
            _staticResolver);
    }

    // ── Tenant: Tier 1 — tenant DB row ──────────────────────────────────────

    [Fact]
    public async Task ResolveTenantPolicy_WhenTenantRowExists_ReturnsDeserializedPolicy()
    {
        var row = PolicyDefinition.Create(
            PolicyScope.Tenant, TenantId, "Read Own Profile", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null},{\"TemplateName\":\"CreatedByMe\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        var policy = await _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(2);
        policy.ResourceType.Should().Be("user");
        policy.Action.Should().Be("read");
    }

    [Fact]
    public async Task ResolveTenantPolicy_EachEvaluationReadsCurrentCommittedPolicy()
    {
        var row = PolicyDefinition.Create(
            PolicyScope.Tenant, TenantId, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        await _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read");
        await _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read");

        _repository.Verify(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    [Fact]
    public async Task ResolveTenantPolicy_AfterTenantDisable_FailsClosedWithoutInvalidation()
    {
        var row = PolicyDefinition.Create(
            PolicyScope.Tenant, TenantId, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        await _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read");
        row.Deactivate();
        await Assert.ThrowsAsync<PolicyResolutionException>(() => _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read"));

        _repository.Verify(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    // ── Tenant: Tier 2 — platform DB row fallback ────────────────────────────

    [Fact]
    public async Task ResolveTenantPolicy_WhenTenantRowAbsent_FallsThroughToPlatformRow()
    {
        var platformRow = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read Own Profile (Platform Default)", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(platformRow);

        var policy = await _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(1);
        _repository.Verify(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ResolveTenantPolicy_AfterPlatformDisable_FailsClosedWithoutInvalidation()
    {
        var platformRow = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(platformRow);

        await _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read");
        platformRow.Deactivate();
        await Assert.ThrowsAsync<PolicyResolutionException>(() => _resolver.ResolveTenantPolicyAsync(TenantId, "user", "read"));

        _repository.Verify(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    // ── Tenant: Tier 3 — static fallback ────────────────────────────────────

    [Fact]
    public async Task ResolveTenantPolicy_WhenTenantAndPlatformRowAbsent_FallsBackToStatic()
    {
        _repository.Setup(r => r.GetAsync(TenantId, "document", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("document", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);

        var staticPolicy = new AbacPolicy
        {
            ResourceType = "document",
            Action = "read",
            Conditions = [new AbacCondition { Template = _registry.Resolve("SameTenant") }]
        };
        _staticResolver.RegisterDefault("document", "read", staticPolicy);

        var policy = await _resolver.ResolveTenantPolicyAsync(TenantId, "document", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(1);
    }

    [Fact]
    public async Task ResolveTenantPolicy_WhenAllTiersAbsent_ReturnsNull()
    {
        _repository.Setup(r => r.GetAsync(TenantId, "unknown", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("unknown", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);

        var policy = await _resolver.ResolveTenantPolicyAsync(TenantId, "unknown", "read");

        policy.Should().BeNull();
    }

    // ── Platform path ────────────────────────────────────────────────────────

    [Fact]
    public async Task ResolvePlatformPolicy_WhenPlatformRowExists_ReturnsPolicy()
    {
        var platformRow = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read Own Profile (Platform Default)", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null},{\"TemplateName\":\"CreatedByMe\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(platformRow);

        var policy = await _resolver.ResolvePlatformPolicyAsync("user", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(2);
        _repository.Verify(r => r.GetAsync(
            It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ResolvePlatformPolicy_WhenNoPlatformRow_ReturnsNull()
    {
        _repository.Setup(r => r.GetPlatformAsync("unknown", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);

        var policy = await _resolver.ResolvePlatformPolicyAsync("unknown", "read");

        policy.Should().BeNull();
    }
}

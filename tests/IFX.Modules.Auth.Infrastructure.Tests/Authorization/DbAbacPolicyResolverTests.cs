using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abac.Templates;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Authorization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Infrastructure.Tests.Authorization;

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
        _registry.Register(new ConditionTemplate { Name = "SameTenant" });
        _registry.Register(new ConditionTemplate { Name = "CreatedByMe" });

        _staticResolver = new StaticAbacPolicyResolver();

        _cache = new MemoryCache(new MemoryCacheOptions());

        _resolver = new DbAbacPolicyResolver(
            _repository.Object,
            _registry,
            _staticResolver,
            _cache,
            Mock.Of<ILogger<DbAbacPolicyResolver>>());
    }

    // ── Tier 1: Tenant DB row ────────────────────────────────────────────────

    [Fact]
    public async Task ResolveAsync_WhenTenantRowExists_ReturnsDeserializedPolicy()
    {
        var row = PolicyDefinition.Create(
            PolicyScope.Tenant, TenantId, "Read Own Profile", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null},{\"TemplateName\":\"CreatedByMe\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        var policy = await _resolver.ResolveAsync(TenantId, "user", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(2);
        policy.ResourceType.Should().Be("user");
        policy.Action.Should().Be("read");
    }

    [Fact]
    public async Task ResolveAsync_CacheHitAvoidsSecondDbCall()
    {
        var row = PolicyDefinition.Create(
            PolicyScope.Tenant, TenantId, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        await _resolver.ResolveAsync(TenantId, "user", "read");
        await _resolver.ResolveAsync(TenantId, "user", "read");

        _repository.Verify(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ResolveAsync_AfterInvalidate_HitsDbAgain()
    {
        var row = PolicyDefinition.Create(
            PolicyScope.Tenant, TenantId, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        await _resolver.ResolveAsync(TenantId, "user", "read");
        _resolver.Invalidate(TenantId, "user", "read");
        await _resolver.ResolveAsync(TenantId, "user", "read");

        _repository.Verify(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    // ── Tier 2: Platform DB row ──────────────────────────────────────────────

    [Fact]
    public async Task ResolveAsync_WhenTenantRowAbsent_FallsThroughToPlatformRow()
    {
        var platformRow = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read Own Profile (Platform Default)", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(platformRow);

        var policy = await _resolver.ResolveAsync(TenantId, "user", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(1);
        _repository.Verify(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ResolveAsync_WhenTenantIdIsNull_SkipsTenantDbAndChecksPlatformRow()
    {
        var platformRow = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read Own Profile (Platform Default)", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null},{\"TemplateName\":\"CreatedByMe\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(platformRow);

        var policy = await _resolver.ResolveAsync(null, "user", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(2);
        _repository.Verify(r => r.GetAsync(
            It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ResolveAsync_AfterInvalidatePlatform_HitsPlatformDbAgain()
    {
        var platformRow = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(platformRow);

        await _resolver.ResolveAsync(TenantId, "user", "read");
        _resolver.InvalidatePlatform("user", "read");
        await _resolver.ResolveAsync(TenantId, "user", "read");

        _repository.Verify(r => r.GetPlatformAsync("user", "read", It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    // ── Tier 3: Static fallback ──────────────────────────────────────────────

    [Fact]
    public async Task ResolveAsync_WhenTenantAndPlatformRowAbsent_FallsBackToStatic()
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

        var policy = await _resolver.ResolveAsync(TenantId, "document", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(1);
    }

    [Fact]
    public async Task ResolveAsync_WhenAllTiersAbsent_ReturnsNull()
    {
        _repository.Setup(r => r.GetAsync(TenantId, "unknown", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);
        _repository.Setup(r => r.GetPlatformAsync("unknown", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);

        var policy = await _resolver.ResolveAsync(TenantId, "unknown", "read");

        policy.Should().BeNull();
    }
}

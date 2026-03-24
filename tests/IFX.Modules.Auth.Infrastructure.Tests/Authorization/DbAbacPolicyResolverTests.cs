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

    [Fact]
    public async Task ResolveAsync_WhenDbRowExists_ReturnsDeserializedPolicy()
    {
        var row = PolicyDefinition.Create(
            TenantId, "Read Own Profile", "user", "read",
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
    public async Task ResolveAsync_WhenNoDbRow_FallsBackToStaticDefault()
    {
        _repository.Setup(r => r.GetAsync(TenantId, "document", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);

        var defaultPolicy = new AbacPolicy
        {
            ResourceType = "document",
            Action = "read",
            Conditions = [new AbacCondition { Template = _registry.Resolve("SameTenant") }]
        };
        _staticResolver.RegisterDefault("document", "read", defaultPolicy);

        var policy = await _resolver.ResolveAsync(TenantId, "document", "read");

        policy.Should().NotBeNull();
        policy!.Conditions.Should().HaveCount(1);
    }

    [Fact]
    public async Task ResolveAsync_WhenNoDbRowAndNoDefault_ReturnsNull()
    {
        _repository.Setup(r => r.GetAsync(TenantId, "unknown", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync((PolicyDefinition?)null);

        var policy = await _resolver.ResolveAsync(TenantId, "unknown", "read");

        policy.Should().BeNull();
    }

    [Fact]
    public async Task ResolveAsync_CacheHitAvoidsSecondDbCall()
    {
        var row = PolicyDefinition.Create(
            TenantId, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        // First call — hits DB
        await _resolver.ResolveAsync(TenantId, "user", "read");
        // Second call — should hit cache
        await _resolver.ResolveAsync(TenantId, "user", "read");

        _repository.Verify(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ResolveAsync_AfterInvalidate_HitsDbAgain()
    {
        var row = PolicyDefinition.Create(
            TenantId, "Read", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]",
            null);

        _repository.Setup(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()))
                   .ReturnsAsync(row);

        await _resolver.ResolveAsync(TenantId, "user", "read");
        _resolver.Invalidate(TenantId, "user", "read");
        await _resolver.ResolveAsync(TenantId, "user", "read");

        _repository.Verify(r => r.GetAsync(TenantId, "user", "read", It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    [Fact]
    public async Task ResolveAsync_WhenTenantIdIsNull_SkipsDbAndUsesStaticDefault()
    {
        var defaultPolicy = new AbacPolicy
        {
            ResourceType = "user",
            Action = "read",
            Conditions = [new AbacCondition { Template = _registry.Resolve("SameTenant") }]
        };
        _staticResolver.RegisterDefault("user", "read", defaultPolicy);

        var policy = await _resolver.ResolveAsync(null, "user", "read");

        policy.Should().NotBeNull();
        _repository.Verify(r => r.GetAsync(
            It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}

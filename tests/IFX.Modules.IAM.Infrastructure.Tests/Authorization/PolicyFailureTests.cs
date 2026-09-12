using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Infrastructure.Access;

namespace IFX.Modules.IAM.Infrastructure.Tests.Authorization;

public class PolicyFailureTests
{
    private static readonly Guid Tenant = Guid.NewGuid();
    private static PolicyDefinition Row(string json) => PolicyDefinition.Create(PolicyScope.Tenant, Tenant, "Test", "user", "read", json, null);

    [Theory]
    [InlineData("[]")]
    [InlineData("not-json")]
    [InlineData("[{\"TemplateName\":\"UnknownTemplate\"}]")]
    [InlineData("[{\"TemplateName\":\"SameTenant\"},{\"TemplateName\":\"UnknownTemplate\"}]")]
    [InlineData("[{\"TemplateName\":\"GlobalRoleIncludes\",\"Parameters\":{\"global_role\":\"PlatformAdmin\"}}]")]
    public async Task Invalid_policy_cannot_drop_conditions_or_fall_back(string json)
    {
        var repository = new Mock<IPolicyDefinitionRepository>(MockBehavior.Strict);
        repository.Setup(x => x.GetAsync(Tenant, "user", "read", It.IsAny<CancellationToken>())).ReturnsAsync(Row(json));
        var error = await Assert.ThrowsAsync<PolicyResolutionException>(() => Resolver(repository).ResolveTenantPolicyAsync(Tenant, "user", "read"));
        Assert.Equal(PolicyFailure.Invalid, error.Failure);
        repository.Verify(x => x.GetPlatformAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Disabled_row_stops_default_fallback()
    {
        var row = Row("[{\"TemplateName\":\"SameTenant\"}]"); row.Deactivate();
        var repository = new Mock<IPolicyDefinitionRepository>();
        repository.Setup(x => x.GetAsync(Tenant, "user", "read", It.IsAny<CancellationToken>())).ReturnsAsync(row);
        var error = await Assert.ThrowsAsync<PolicyResolutionException>(() => Resolver(repository).ResolveTenantPolicyAsync(Tenant, "user", "read"));
        Assert.Equal(PolicyFailure.Disabled, error.Failure);
        repository.Verify(x => x.GetPlatformAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Database_failure_does_not_use_registered_static_allow_policy()
    {
        var repository = new Mock<IPolicyDefinitionRepository>();
        repository.Setup(x => x.GetAsync(Tenant, "user", "read", It.IsAny<CancellationToken>())).ThrowsAsync(new IOException());
        var resolver = Resolver(repository);
        resolver.RegisterDefault("user", "read", new AbacPolicy { Conditions = [new() { Template = BuiltInTemplates.SameTenant }] });
        var error = await Assert.ThrowsAsync<PolicyResolutionException>(() => resolver.ResolveTenantPolicyAsync(Tenant, "user", "read"));
        Assert.Equal(PolicyFailure.Unavailable, error.Failure);
    }

    [Fact]
    public async Task Separate_instances_observe_policy_change_and_version_without_cache_invalidation()
    {
        var row = Row("[{\"TemplateName\":\"SameTenant\"}]");
        var repository = new Mock<IPolicyDefinitionRepository>();
        repository.Setup(x => x.GetAsync(Tenant, "user", "read", It.IsAny<CancellationToken>())).ReturnsAsync(() => row);
        var first = Resolver(repository); var second = Resolver(repository);
        var before = await first.ResolveTenantPolicyAsync(Tenant, "user", "read");
        row.Update("Changed", "[{\"TemplateName\":\"CreatedByMe\"}]", null);
        var after = await second.ResolveTenantPolicyAsync(Tenant, "user", "read");
        Assert.NotEqual(before!.Version, after!.Version);
        Assert.Equal("tenant-custom", after.Classification);
        Assert.Equal(after.Version, (await first.ResolveTenantPolicyAsync(Tenant, "user", "read"))!.Version);
    }

    [Fact]
    public async Task Cancellation_is_not_a_policy_absence()
    {
        using var ct = new CancellationTokenSource(); ct.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Resolver(new()).ResolveTenantPolicyAsync(Tenant, "user", "read", ct.Token));
    }

    private static DbAbacPolicyResolver Resolver(Mock<IPolicyDefinitionRepository> repository)
    {
        var registry = new AbacTemplateRegistry(); BuiltInTemplates.Register(registry);
        return new(repository.Object, registry, new StaticAbacPolicyResolver());
    }
}

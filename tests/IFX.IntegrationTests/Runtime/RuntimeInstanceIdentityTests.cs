using IFX.ApiHost.Runtime;

namespace IFX.IntegrationTests.Runtime;

public sealed class RuntimeInstanceIdentityTests
{
    [Fact]
    public void Create_TwoProcessStarts_ProducesUniqueBoundedIdentities()
    {
        var first = RuntimeInstanceIdentity.Create(RuntimeRole.Worker, "NODE_A.with spaces", 42);
        var second = RuntimeInstanceIdentity.Create(RuntimeRole.Worker, "NODE_A.with spaces", 42);

        first.Value.Should().NotBe(second.Value);
        first.Value.Should().MatchRegex("^ifx-worker-node-a-with-spaces-42-[0-9a-f]{32}$");
        first.Value.Length.Should().BeLessThanOrEqualTo(128);
    }
}

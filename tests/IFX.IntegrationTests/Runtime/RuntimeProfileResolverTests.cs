using IFX.ApiHost.Runtime;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

namespace IFX.IntegrationTests.Runtime;

public sealed class RuntimeProfileResolverTests
{
    [Theory]
    [InlineData("api", true, false)]
    [InlineData("worker", false, true)]
    [InlineData("all", true, true)]
    public void Resolve_KnownRole_SelectsExpectedCapabilities(string role, bool api, bool worker)
    {
        var profile = RuntimeProfileResolver.Resolve(Config(("Runtime:Role", role)), new TestEnvironment("Development"));

        profile.Capabilities.Api.Should().Be(api);
        profile.Capabilities.HasWorkerExecution.Should().Be(worker);
    }

    [Fact]
    public void Resolve_UnknownRole_FailsWithStableReason()
    {
        var action = () => RuntimeProfileResolver.Resolve(Config(("Runtime:Role", "sidecar")), new TestEnvironment("Development"));

        action.Should().Throw<RuntimeConfigurationException>()
            .Which.ReasonCode.Should().Be("G04-RUNTIME-UNKNOWN-ROLE");
    }

    [Fact]
    public void Resolve_EmptyWorker_FailsWithStableReason()
    {
        var configuration = Config(
            ("Runtime:Role", "worker"),
            ("Runtime:Capabilities:HangfireServer", "false"),
            ("Runtime:Capabilities:Dispatcher", "false"),
            ("Runtime:Capabilities:Consumers", "false"),
            ("Runtime:Capabilities:RecurringScheduler", "false"));

        var action = () => RuntimeProfileResolver.Resolve(configuration, new TestEnvironment("Development"));

        action.Should().Throw<RuntimeConfigurationException>()
            .Which.ReasonCode.Should().Be("G04-RUNTIME-WORKER-CAPABILITY-MISMATCH");
    }

    [Fact]
    public void Resolve_ProductionAllWithoutApproval_FailsWithStableReason()
    {
        var action = () => RuntimeProfileResolver.Resolve(Config(("Runtime:Role", "all")), new TestEnvironment("Production"));

        action.Should().Throw<RuntimeConfigurationException>()
            .Which.ReasonCode.Should().Be("G04-RUNTIME-PRODUCTION-ALL-DISALLOWED");
    }

    [Fact]
    public void Resolve_ApiWithWorkerExecution_FailsWithStableReason()
    {
        var configuration = Config(("Runtime:Role", "api"), ("Runtime:Capabilities:Dispatcher", "true"));

        var action = () => RuntimeProfileResolver.Resolve(configuration, new TestEnvironment("Development"));

        action.Should().Throw<RuntimeConfigurationException>()
            .Which.ReasonCode.Should().Be("G04-RUNTIME-API-CAPABILITY-MISMATCH");
    }

    private static IConfiguration Config(params (string Key, string Value)[] values) =>
        new ConfigurationBuilder().AddInMemoryCollection(values.ToDictionary(x => x.Key, x => (string?)x.Value)).Build();

    private sealed class TestEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;
        public string ApplicationName { get; set; } = "IFX.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}

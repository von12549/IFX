using App.Abstractions;
using IFX.ApiHost.Runtime;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Runtime;

public sealed class StartupBoundaryVerifierTests
{
    [Fact]
    public void ValidateComposition_ValidManifest_ReturnsManifestOrder()
    {
        var manifest = Manifest("auth", "crm", "registry", "holdings", "transaction");
        var installers = new IModuleInstaller[] { new Installer("Transaction"), new Installer("Auth"), new Installer("CRM"), new Installer("Holdings"), new Installer("Registry") };

        var ordered = StartupBoundaryVerifier.ValidateComposition(installers, manifest, Release(manifest), Profile());

        ordered.Select(x => x.ModuleName).Should().Equal("Auth", "CRM", "Registry", "Holdings", "Transaction");
    }

    [Fact]
    public void ValidateComposition_DuplicateInstaller_FailsWithStableReason()
    {
        var manifest = Manifest("auth", "crm", "registry", "holdings", "transaction");
        var installers = new IModuleInstaller[] { new Installer("Auth"), new Installer("Auth"), new Installer("CRM"), new Installer("Registry"), new Installer("Holdings"), new Installer("Transaction") };

        var action = () => StartupBoundaryVerifier.ValidateComposition(installers, manifest, Release(manifest), Profile());

        action.Should().Throw<StartupValidationException>().Which.ReasonCode.Should().Be("G04-STARTUP-MODULE-COMPOSITION-INVALID");
    }

    [Fact]
    public void ValidateComposition_ReleaseMismatch_FailsWithStableReason()
    {
        var manifest = Manifest("auth", "crm", "registry", "holdings", "transaction");
        var release = Release(manifest) with { ReleaseId = "different" };

        var action = () => StartupBoundaryVerifier.ValidateComposition(Array.Empty<IModuleInstaller>(), manifest, release, Profile());

        action.Should().Throw<StartupValidationException>().Which.ReasonCode.Should().Be("G04-STARTUP-RELEASE-MISMATCH");
    }

    private static ModuleManifest Manifest(params string[] ids) => new(1, "1.0.0-g04", ids.Select(id => new ModuleManifestEntry(id, "1.0.0", true, [], [], id, [], [], [])).ToArray());
    private static ReleaseRuntimeManifest Release(ModuleManifest manifest) => new(1, manifest.ReleaseVersion, "ifx-backend", new HostArtifactManifest("ifx-host", "sha256:test", ["api", "worker", "all"]), manifest.Modules.Select(x => x.ModuleId).ToArray());
    private static RuntimeProfile Profile() => new(RuntimeRole.Api, new RuntimeCapabilities(true, true, false, false, false, false));

    private sealed class Installer(string name) : IModuleInstaller
    {
        public string ModuleName => name;
        public IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration) => services;
        public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder) => builder;
    }
}

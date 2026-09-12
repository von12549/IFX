using IFX.ApiHost.Configuration;
using IFX.Modules.IAM.Composition;
using IFX.Platform.Authentication.Contracts.V1;
using IFX.Platform.Authorization.Contracts.V1;
using IFX.Modules.IAM.Contracts.V1.Authorization;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Infrastructure.Access;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Composition;

public sealed class IamSecurityCompositionTests
{
    [Theory]
    [InlineData("api")]
    [InlineData("worker")]
    public void Security_capabilities_have_one_composition_owner_in_each_runtime_role(string runtimeRole)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Runtime:Role"] = runtimeRole, ["Authentication:Provider"] = "Cognito",
            ["ConnectionStrings:AuthDatabase"] = "Server=unused;Database=unused;Integrated Security=true"
        }).Build();
        var services = new ServiceCollection(); services.AddIamModule(config);
        if (runtimeRole == "api") services.AddAuthAuthentication(config);
        Assert.Single(services, d => d.ServiceType == typeof(IAuthorizationEvaluationContract));
        Assert.Single(services, d => d.ServiceType == typeof(ITokenValidationContract));
        Assert.Single(services, d => d.ServiceType == typeof(IResourceAuthorizationContract));
        Assert.Single(services, d => d.ServiceType == typeof(IExecutionIdentityFacts));
        Assert.Single(services, d => d.ServiceType == typeof(VerifiedIdentityFacts));
    }

    [Theory]
    [InlineData(typeof(IAuthorizationEvaluationContract))]
    [InlineData(typeof(ITokenValidationContract))]
    [InlineData(typeof(IResourceAuthorizationContract))]
    public void Contracts_assembly_does_not_reference_sdk_runtime_http_or_persistence(Type contract)
    {
        Assert.DoesNotContain(contract.Assembly.GetReferencedAssemblies(), reference =>
            reference.Name!.Contains("Infrastructure") || reference.Name.Contains("Runtime") && !reference.Name.StartsWith("System.") ||
            reference.Name.StartsWith("Amazon") || reference.Name.StartsWith("Auth0") || reference.Name.StartsWith("Microsoft."));
    }
}

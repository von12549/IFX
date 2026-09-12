using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using IFX.ApiHost.Authentication;
using IFX.ApiHost.Authorization;
using IFX.Modules.IAM.Composition;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Platform.Authentication.Composition;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.IdentityModel.Tokens;
using Moq;

namespace IFX.IntegrationTests.Runtime;

public sealed class AuthenticationBoundaryTests
{
    [Fact]
    public async Task Bearer_entry_preserves_shared_options_and_discards_external_authorization_claims()
    {
        var configuration = new IdpConfigurationEntry { IdpId = Guid.NewGuid(), Issuer = "https://issuer.example", Authority = "https://issuer.example",
            ExpectedAudiences = ["client"], AllowedAlgorithms = ["RS256"] };
        var configurations = new Mock<IIdpConfigurationService>();
        configurations.Setup(c => c.GetByIssuerAsync(configuration.Issuer, It.IsAny<CancellationToken>())).ReturnsAsync(configuration);
        var validation = new Mock<IHostTokenValidation>();
        validation.Setup(v => v.ValidateAsync(It.IsAny<string>(), configuration.Issuer, configuration.Authority,
            It.IsAny<IReadOnlyList<string>>(), It.IsAny<IReadOnlyList<string>>(), It.IsAny<int>(), It.IsAny<CancellationToken>(), "aud", null))
            .ReturnsAsync(("verified-subject", "validated"));
        var events = new DynamicJwtBearerEvents(configurations.Object, validation.Object, NullLogger<DynamicJwtBearerEvents>.Instance);
        var parameters = new TokenValidationParameters { ValidAudience = "sentinel" };
        var options = new JwtBearerOptions { TokenValidationParameters = parameters };
        var context = Context(options, new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(configuration.Issuer,
            claims: [new("user_id", "attacker-id"), new("role", "GlobalAdmin")])));
        await events.MessageReceived(context);
        Assert.True(context.Result?.Succeeded);
        Assert.Same(parameters, options.TokenValidationParameters);
        Assert.Equal("sentinel", parameters.ValidAudience);
        Assert.Equal("verified-subject", context.Principal?.FindFirst("sub")?.Value);
        Assert.False(context.Principal?.HasClaim(claim => claim.Type is "user_id" or "role" or "tenant"));
    }

    [Fact]
    public async Task Default_client_fallback_is_bound_to_exact_configured_issuer_and_revocation_is_not_cached()
    {
        const string issuer = "https://issuer.example";
        var configured = Idp.Create("configured", issuer, issuer, "", "");
        var external = Idp.Create("external", "https://external.example", "https://external.example", "", "");
        var work = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        work.Setup(w => w.Idps.GetEnabledAsync(It.IsAny<CancellationToken>())).ReturnsAsync([configured, external]);
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:AuthDatabase"] = "Server=unused;Database=unused;Integrated Security=true",
            ["CognitoSettings:Authority"] = issuer, ["CognitoSettings:ClientId"] = "configured-client"
        }).Build();
        var services = new ServiceCollection();
        new AuthModuleInstaller().InstallServices(services, configuration);
        services.AddSingleton<IConfiguration>(configuration);
        services.AddScoped(_ => work.Object);
        using var provider = services.BuildServiceProvider();
        using (var scope = provider.CreateScope())
        {
            var entries = await scope.ServiceProvider.GetRequiredService<IAuthIdpConfigurationReader>().ReadEnabledAsync();
            Assert.Contains("configured-client", entries.Single(entry => entry.Issuer == issuer).ExpectedAudiences);
            Assert.Equal("client_id", entries.Single(entry => entry.Issuer == issuer).AudienceClaim);
            Assert.Equal("[]", entries.Single(entry => entry.Issuer == external.Issuer).ExpectedAudiences);
        }
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var host = new IdpConfigurationService(provider.GetRequiredService<IServiceScopeFactory>(), Mock.Of<IAuthIdpCacheVersion>(), cache, NullLogger<IdpConfigurationService>.Instance);
        Assert.NotNull(await host.GetByIssuerAsync(issuer));
        work.Setup(w => w.Idps.GetEnabledAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);
        Assert.Null(await host.GetByIssuerAsync(issuer));
    }

    [Fact]
    public async Task Unknown_or_disabled_issuer_is_rejected_before_protocol_execution()
    {
        var validation = new Mock<IHostTokenValidation>(MockBehavior.Strict);
        var events = new DynamicJwtBearerEvents(Mock.Of<IIdpConfigurationService>(), validation.Object, NullLogger<DynamicJwtBearerEvents>.Instance);
        var context = Context(new(), new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(issuer: "https://unknown.example")));
        await events.MessageReceived(context);
        Assert.NotNull(context.Result?.Failure);
        validation.VerifyNoOtherCalls();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Local_admission_rejection_or_exception_never_preserves_authenticated_principal(bool throws)
    {
        var facade = new Mock<IAuthUserProvisioningFacade>();
        if (throws) facade.Setup(f => f.GetOrProvisionAsync(It.IsAny<AuthUserProvisioningRequest>(), It.IsAny<CancellationToken>())).ThrowsAsync(new InvalidOperationException());
        else facade.Setup(f => f.GetOrProvisionAsync(It.IsAny<AuthUserProvisioningRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new AuthUserProvisioningResult(false, "rejected", Guid.Empty, null, [], [], [], []));
        using var services = new ServiceCollection().AddScoped(_ => facade.Object).BuildServiceProvider();
        var http = new DefaultHttpContext();
        http.Items["IdpConfiguration"] = new IdpConfigurationEntry { Issuer = "https://issuer.example" };
        var transformation = new UserPermissionClaimsTransformation(services, new HttpContextAccessor { HttpContext = http }, NullLogger<UserPermissionClaimsTransformation>.Instance);
        var principal = new ClaimsPrincipal(new ClaimsIdentity([new("iss", "https://issuer.example"), new("sub", "subject"), new("user_id", "forged")], "Bearer"));
        var result = await transformation.TransformAsync(principal);
        Assert.False(result.Identity?.IsAuthenticated ?? false);
        Assert.Empty(result.Claims);
        facade.Verify(f => f.GetOrProvisionAsync(It.IsAny<AuthUserProvisioningRequest>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    private static MessageReceivedContext Context(JwtBearerOptions options, string token)
    {
        var context = new DefaultHttpContext();
        context.Request.Headers.Authorization = "Bearer " + token;
        return new(context, new AuthenticationScheme("Bearer", null, typeof(JwtBearerHandler)), options);
    }
}

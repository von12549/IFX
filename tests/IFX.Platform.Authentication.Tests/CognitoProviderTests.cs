using Amazon.CognitoIdentityProvider;
using Amazon.CognitoIdentityProvider.Model;
using IFX.Platform.Authentication.Contracts.V1;
using IFX.Platform.Authentication.Infrastructure.Cognito;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace IFX.Platform.Authentication.Tests;

public sealed class CognitoProviderTests
{
    [Fact]
    public async Task Registration_confirmation_refresh_revoke_and_logout_use_separate_capabilities()
    {
        var sdk = new Mock<IAmazonCognitoIdentityProvider>(MockBehavior.Strict);
        sdk.Setup(s => s.SignUpAsync(It.Is<SignUpRequest>(request => request.ClientId == "client" && request.Password == "test-password"), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SignUpResponse { UserSub = "subject", UserConfirmed = false });
        sdk.Setup(s => s.ConfirmSignUpAsync(It.Is<ConfirmSignUpRequest>(request => request.ConfirmationCode == "test-code"), It.IsAny<CancellationToken>())).ReturnsAsync(new ConfirmSignUpResponse());
        sdk.Setup(s => s.AdminInitiateAuthAsync(It.Is<AdminInitiateAuthRequest>(request => request.AuthParameters["REFRESH_TOKEN"] == "test-refresh"), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new AdminInitiateAuthResponse { AuthenticationResult = new() { AccessToken = "new-access", IdToken = "new-id", ExpiresIn = 300, TokenType = "Bearer" } });
        sdk.Setup(s => s.RevokeTokenAsync(It.Is<RevokeTokenRequest>(request => request.Token == "test-refresh"), It.IsAny<CancellationToken>())).ReturnsAsync(new RevokeTokenResponse());
        sdk.Setup(s => s.GlobalSignOutAsync(It.Is<GlobalSignOutRequest>(request => request.AccessToken == "new-access"), It.IsAny<CancellationToken>())).ReturnsAsync(new GlobalSignOutResponse());
        var tokens = new Mock<ITokenValidationContract>();
        tokens.Setup(t => t.ValidateAsync("new-id", It.Is<IssuerValidationOptions>(options => options.Issuer == "https://issuer.example" && options.Audiences.Single() == "client"), null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TokenValidationResponse(new("https://issuer.example", "subject"), "validated"));
        var provider = new CognitoIdentityProvider(sdk.Object, Options.Create(new CognitoOptions { ClientId = "client", ClientSecret = "test-secret", Authority = "https://issuer.example" }), NullLogger<CognitoIdentityProvider>.Instance, tokens.Object);
        IExternalAccountContract accounts = provider;
        ITokenLifecycleContract lifecycle = provider;
        Assert.Equal("subject", (await accounts.SignUpAsync("email@example.test", "test-password", "user", "", "", "", "")).Subject);
        Assert.True(await accounts.ConfirmSignUpAsync("user", "test-code"));
        var refresh = await lifecycle.RefreshTokenAsync("test-refresh", "user");
        Assert.True(refresh.Success);
        Assert.Equal("test-refresh", refresh.RefreshToken);
        Assert.Equal("subject", refresh.Subject);
        Assert.True(await lifecycle.RevokeTokenAsync("test-refresh"));
        Assert.True(await lifecycle.SignOutAsync(refresh.AccessToken!));
        sdk.VerifyAll();
        tokens.VerifyAll();
    }
}

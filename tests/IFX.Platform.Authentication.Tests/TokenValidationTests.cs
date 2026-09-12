using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using IFX.Platform.Authentication.Contracts.V1;
using IFX.Platform.Authentication.Runtime;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace IFX.Platform.Authentication.Tests;

public sealed class TokenValidationTests
{
    internal static string Token(SecurityKey key, string issuer = "https://issuer.example", string audience = "client",
        string nonce = "nonce", DateTime? expires = null, string subject = "subject") => new JwtSecurityTokenHandler().WriteToken(
        new JwtSecurityToken(issuer, audience, [new("sub", subject), new("nonce", nonce), new("user_id", "untrusted-local-id"), new("role", "GlobalAdmin")],
            DateTime.UtcNow.AddHours(-2), expires ?? DateTime.UtcNow.AddMinutes(5), new SigningCredentials(key, SecurityAlgorithms.RsaSha256)));

    internal static IssuerValidationOptions Trust(string issuer = "https://issuer.example", string audience = "client")
        => new(issuer, issuer, [audience], [SecurityAlgorithms.RsaSha256], 0);

    internal static TokenValidationService Validator(SecurityKey key, string issuer = "https://issuer.example")
    {
        var metadata = new OpenIdConnectConfiguration { Issuer = issuer };
        metadata.SigningKeys.Add(key);
        return new(_ => new StaticConfigurationManager<OpenIdConnectConfiguration>(metadata));
    }

    [Theory]
    [InlineData("valid", true)]
    [InlineData("issuer", false)]
    [InlineData("audience", false)]
    [InlineData("signature", false)]
    [InlineData("expired", false)]
    [InlineData("nonce", false)]
    [InlineData("subject", false)]
    public async Task Cryptographic_validation_rejects_invalid_identity(string scenario, bool valid)
    {
        using var rsa = RSA.Create(2048);
        using var other = RSA.Create(2048);
        var key = new RsaSecurityKey(rsa) { KeyId = "key" };
        var token = Token(scenario == "signature" ? new RsaSecurityKey(other) { KeyId = "key" } : key,
            issuer: scenario == "issuer" ? "https://attacker.example" : "https://issuer.example",
            audience: scenario == "audience" ? "other" : "client", nonce: scenario == "nonce" ? "other" : "nonce",
            expires: scenario == "expired" ? DateTime.UtcNow.AddMinutes(-5) : null,
            subject: scenario == "subject" ? "" : "subject");
        var result = await Validator(key).ValidateAsync(token, Trust(), "nonce");
        Assert.Equal(valid, result.IsValid);
        if (valid) Assert.Equal(new VerifiedIdentityDto("https://issuer.example", "subject"), result.Identity);
    }

    [Fact]
    public async Task Parallel_issuers_have_independent_validation_parameters()
    {
        using var first = RSA.Create(2048);
        using var second = RSA.Create(2048);
        var a = new RsaSecurityKey(first) { KeyId = "same-kid" };
        var b = new RsaSecurityKey(second) { KeyId = "same-kid" };
        var service = new TokenValidationService(authority =>
        {
            var metadata = new OpenIdConnectConfiguration { Issuer = authority };
            metadata.SigningKeys.Add(authority == "https://a.example" ? a : b);
            return new StaticConfigurationManager<OpenIdConnectConfiguration>(metadata);
        });
        var tasks = Enumerable.Range(0, 40).Select(async index =>
        {
            var issuer = index % 2 == 0 ? "https://a.example" : "https://b.example";
            var key = index % 2 == 0 ? a : b;
            var result = await service.ValidateAsync(Token(key, issuer, issuer), Trust(issuer, issuer));
            Assert.Equal(issuer, result.Identity?.Issuer);
            Assert.False((await service.ValidateAsync(Token(key, issuer, "wrong"), Trust(issuer, issuer))).IsValid);
        });
        await Task.WhenAll(tasks);
    }

    [Fact]
    public async Task Cognito_access_token_checks_client_id_and_token_use_without_requiring_aud()
    {
        using var rsa = RSA.Create(2048);
        var key = new RsaSecurityKey(rsa);
        string AccessToken(string clientId, string tokenUse) => new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(
            "https://issuer.example", claims: [new("sub", "subject"), new("client_id", clientId), new("token_use", tokenUse)],
            expires: DateTime.UtcNow.AddMinutes(5), signingCredentials: new(key, SecurityAlgorithms.RsaSha256)));
        var trust = Trust() with { AudienceClaim = "client_id", RequiredTokenUse = "access" };
        var validator = Validator(key);
        Assert.True((await validator.ValidateAsync(AccessToken("client", "access"), trust)).IsValid);
        Assert.False((await validator.ValidateAsync(AccessToken("other-client", "access"), trust)).IsValid);
        Assert.False((await validator.ValidateAsync(AccessToken("client", "id"), trust)).IsValid);
    }

    [Fact]
    public async Task Metadata_mismatch_and_unavailable_provider_fail_closed()
    {
        using var rsa = RSA.Create(2048);
        var key = new RsaSecurityKey(rsa);
        Assert.Equal("metadata_issuer_mismatch", (await Validator(key, "https://different.example").ValidateAsync(Token(key), Trust())).ReasonCode);
        var unavailable = new TokenValidationService(_ => throw new HttpRequestException());
        Assert.Equal("validation_unavailable", (await unavailable.ValidateAsync(Token(key), Trust())).ReasonCode);
        Assert.False((await Validator(key).ValidateAsync(Token(key), Trust() with { Audiences = [] })).IsValid);
        Assert.False((await Validator(key).ValidateAsync(Token(key), Trust() with { Algorithms = ["none"] })).IsValid);
    }
}

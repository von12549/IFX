using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using IFX.Platform.Authentication.Contracts.V1;
using IFX.Platform.Authentication.Runtime;
using Microsoft.IdentityModel.Tokens;

namespace IFX.Platform.Authentication.Tests;

public sealed class OidcProtocolTests
{
    private const string Binding = "test-browser-binding-longer-than-thirty-two-characters";
    private static OidcClientOptions Client(string callback = "https://app.example/callback") => new()
    {
        Issuer = "https://issuer.example", Authority = "https://issuer.example", ClientId = "client",
        AuthorizationEndpoint = "https://issuer.example/authorize", TokenEndpoint = "https://issuer.example/token",
        UserInfoEndpoint = "https://issuer.example/userinfo", LogoutEndpoint = "https://issuer.example/logout",
        CallbackUrl = callback, LogoutCallbackUrl = "https://app.example/logout", ClientSecret = "test-client-secret"
    };
    private static Dictionary<string, string> Fields(string encoded) => encoded.TrimStart('?').Split('&')
        .Select(field => field.Split('=', 2)).ToDictionary(field => Uri.UnescapeDataString(field[0]), field => Uri.UnescapeDataString(field[1]));

    [Theory]
    [InlineData("valid", true)]
    [InlineData("nonce", false)]
    [InlineData("subject", false)]
    [InlineData("callback", false)]
    [InlineData("browser", false)]
    [InlineData("state", false)]
    [InlineData("network", false)]
    [InlineData("missing_id_token", false)]
    public async Task Callback_is_bound_to_browser_client_pkce_and_verified_identity(string scenario, bool expected)
    {
        using var rsa = RSA.Create(2048);
        var key = new RsaSecurityKey(rsa);
        Dictionary<string, string> authorization = [];
        var exchanges = 0;
        using var handler = new CallbackHandler(async request =>
        {
            if (request.RequestUri!.AbsolutePath == "/token")
            {
                Interlocked.Increment(ref exchanges);
                var fields = Fields(await request.Content!.ReadAsStringAsync());
                var challenge = Convert.ToBase64String(SHA256.HashData(Encoding.ASCII.GetBytes(fields["code_verifier"])))
                    .TrimEnd('=').Replace('+', '-').Replace('/', '_');
                Assert.Equal(authorization["code_challenge"], challenge);
                Assert.Equal(authorization["redirect_uri"], fields["redirect_uri"]);
                if (scenario == "network") throw new HttpRequestException("test unavailable");
                return Json(new { access_token = "test-access-token", expires_in = 300,
                    id_token = scenario == "missing_id_token" ? null : TokenValidationTests.Token(key, nonce: scenario == "nonce" ? "wrong" : authorization["nonce"]) });
            }
            Assert.Equal("test-access-token", request.Headers.Authorization?.Parameter);
            return Json(new { sub = scenario == "subject" ? "different-subject" : "subject", email_verified = "true" });
        });
        using var client = new HttpClient(handler);
        var factory = Mock.Of<IHttpClientFactory>(factory => factory.CreateClient("Authentication.Oidc") == client);
        var service = new OidcProtocolService(factory, TokenValidationTests.Validator(key));
        var begin = service.Begin(Client(), Binding);
        authorization = Fields(new Uri(begin.Url).Query);
        Assert.False(authorization.ContainsKey("code_verifier"));
        Assert.False(authorization.ContainsKey("client_secret"));
        var result = await service.RedeemAsync(Client(scenario == "callback" ? "https://app.example/other" : "https://app.example/callback"),
            "test-code", scenario == "state" ? "unknown" : begin.State, scenario == "browser" ? "wrong-browser" : Binding);
        Assert.Equal(expected, result.Success);
        if (scenario is "state" or "callback" or "browser") Assert.Equal(0, exchanges);
        Assert.Equal(scenario == "state", (await service.RedeemAsync(Client(), "test-code", begin.State, Binding)).Success);
    }

    [Fact]
    public async Task Simultaneous_callbacks_exchange_code_only_once()
    {
        var exchanges = 0;
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var handler = new CallbackHandler(async _ =>
        {
            Interlocked.Increment(ref exchanges);
            entered.SetResult();
            await release.Task;
            return new(HttpStatusCode.BadRequest);
        });
        using var client = new HttpClient(handler);
        var service = new OidcProtocolService(Mock.Of<IHttpClientFactory>(factory => factory.CreateClient("Authentication.Oidc") == client), Mock.Of<ITokenValidationContract>());
        var begin = service.Begin(Client(), Binding);
        var first = service.RedeemAsync(Client(), "code", begin.State, Binding);
        await entered.Task;
        var second = await service.RedeemAsync(Client(), "code", begin.State, Binding);
        release.SetResult();
        Assert.False((await first).Success);
        Assert.Equal("invalid_login_transaction", second.ErrorMessage);
        Assert.Equal(1, exchanges);
    }

    [Fact]
    public async Task Expired_transaction_never_exchanges_credentials()
    {
        var clock = new TestClock();
        var factory = new Mock<IHttpClientFactory>(MockBehavior.Strict);
        var service = new OidcProtocolService(factory.Object, Mock.Of<ITokenValidationContract>(), clock);
        var begin = service.Begin(Client(), Binding);
        clock.Now = clock.Now.AddMinutes(11);
        Assert.Equal("invalid_login_transaction", (await service.RedeemAsync(Client(), "code", begin.State, Binding)).ErrorMessage);
        factory.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Discovery_requires_exact_issuer_and_https()
    {
        using var handler = new CallbackHandler(_ => Task.FromResult(Json(new { issuer = "https://wrong.example", userinfo_endpoint = "https://wrong.example/info" })));
        using var client = new HttpClient(handler);
        var service = new OidcProtocolService(Mock.Of<IHttpClientFactory>(factory => factory.CreateClient("Authentication.Oidc") == client), Mock.Of<ITokenValidationContract>());
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.DiscoverAsync("https://issuer.example"));
        await Assert.ThrowsAsync<ArgumentException>(() => service.DiscoverAsync("http://issuer.example"));
    }

    private static HttpResponseMessage Json(object body) => new(HttpStatusCode.OK) { Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json") };
    private sealed class TestClock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = DateTimeOffset.UtcNow;
        public override DateTimeOffset GetUtcNow() => Now;
    }
    private sealed class CallbackHandler(Func<HttpRequestMessage, Task<HttpResponseMessage>> callback) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => callback(request);
    }
}

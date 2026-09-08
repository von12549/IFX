using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using IFX.ApiHost.Middleware;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.IntegrationTests.Fixtures;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace IFX.IntegrationTests.Middleware;

public sealed class HttpContextBoundaryTests(CustomWebApplicationFactory factory)
    : IClassFixture<CustomWebApplicationFactory>
{
    [Fact]
    public async Task Anonymous_request_receives_a_canonical_internal_correlation_id()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health/live");

        response.Headers.TryGetValues(HttpCorrelationMiddleware.CorrelationHeader, out var values).Should().BeTrue();
        Guid.TryParseExact(values!.Single(), "D", out var correlationId).Should().BeTrue();
        correlationId.Should().NotBe(Guid.Empty);
    }

    [Fact]
    public async Task Public_ingress_does_not_adopt_an_untrusted_correlation_id()
    {
        using var client = factory.CreateClient();
        var untrusted = Guid.NewGuid();
        client.DefaultRequestHeaders.Add(HttpCorrelationMiddleware.CorrelationHeader, untrusted.ToString("D"));

        var response = await client.GetAsync("/health/live");
        var returned = Guid.Parse(response.Headers.GetValues(HttpCorrelationMiddleware.CorrelationHeader).Single());

        returned.Should().NotBe(untrusted);
    }

    [Fact]
    public async Task Trusted_gateway_can_propagate_a_valid_correlation_id_when_enabled()
    {
        using var configured = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
                new Dictionary<string, string?>
                {
                    ["HttpContextBoundary:AllowTrustedGatewayCorrelationPropagation"] = "true",
                    ["HttpContextBoundary:TrustedGatewayAddresses:0"] = IPAddress.Loopback.ToString()
                }));
            builder.ConfigureServices(services => services.AddSingleton<IStartupFilter, LoopbackRemoteAddressFilter>());
        });
        using var client = configured.CreateClient();
        var propagated = Guid.NewGuid();
        client.DefaultRequestHeaders.Add(HttpCorrelationMiddleware.CorrelationHeader, propagated.ToString("D"));

        var response = await client.GetAsync("/health/live");
        var returned = Guid.Parse(response.Headers.GetValues(HttpCorrelationMiddleware.CorrelationHeader).Single());

        returned.Should().Be(propagated);
    }

    [Fact]
    public async Task Malformed_traceparent_starts_a_local_trace_without_failing_the_request()
    {
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.TryAddWithoutValidation("traceparent", "not-a-trace");

        var response = await client.GetAsync("/health/live");

        response.StatusCode.Should().NotBe(HttpStatusCode.BadRequest);
        response.Headers.Contains(HttpCorrelationMiddleware.CorrelationHeader).Should().BeTrue();
    }

    [Fact]
    public async Task Missing_tenant_header_uses_the_authenticated_primary_member_tenant()
    {
        using var client = factory.CreateAuthenticatedClient("Role:list");

        var response = await client.GetAsync("/api/v1/role");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Authenticated_member_can_select_a_second_tenant()
    {
        using var client = factory.CreateAuthenticatedClient("Role:list");
        var selectedTenant = Guid.NewGuid();
        client.DefaultRequestHeaders.Add(TestAuthHandler.TenantsHeader, selectedTenant.ToString("D"));
        client.DefaultRequestHeaders.Add("X-Tenant-Id", selectedTenant.ToString("D"));

        var response = await client.GetAsync("/api/v1/role");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Theory]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public async Task Explicit_malformed_tenant_never_falls_back(string tenantHeader)
    {
        using var client = factory.CreateAuthenticatedClient("Role:list");
        client.DefaultRequestHeaders.TryAddWithoutValidation("X-Tenant-Id", tenantHeader);

        var response = await client.GetAsync("/api/v1/role");
        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        body!.ErrorCode.Should().Be("tenant_context_invalid");
        body.Error.Should().Be("The tenant context is invalid.");
    }

    [Fact]
    public async Task Duplicate_tenant_header_is_rejected()
    {
        using var client = factory.CreateAuthenticatedClient("Role:list");
        client.DefaultRequestHeaders.TryAddWithoutValidation(
            "X-Tenant-Id",
            new[] { TestAuthHandler.DefaultTenantId.ToString("D"), Guid.NewGuid().ToString("D") });

        var response = await client.GetAsync("/api/v1/role");
        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        body!.ErrorCode.Should().Be("tenant_context_invalid");
    }

    [Fact]
    public async Task Tenant_outside_actor_membership_is_denied_without_fallback()
    {
        using var client = factory.CreateAuthenticatedClient("Role:list");
        client.DefaultRequestHeaders.Add("X-Tenant-Id", Guid.NewGuid().ToString("D"));

        var response = await client.GetAsync("/api/v1/role");
        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
        body!.ErrorCode.Should().Be("tenant_access_denied");
    }

    [Fact]
    public async Task Global_administrator_must_select_a_tenant_explicitly()
    {
        using var configured = CreateGlobalAdministratorFactory(TestAuthHandler.DefaultTenantId);
        using var client = CreateAuthenticatedClient(configured, "Role:list");

        var response = await client.GetAsync("/api/v1/role");
        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        body!.ErrorCode.Should().Be("tenant_context_required");
    }

    [Fact]
    public async Task Global_administrator_can_use_explicit_tenant_and_platform_scopes()
    {
        var selectedTenant = Guid.NewGuid();
        using var configured = CreateGlobalAdministratorFactory(selectedTenant);
        using var client = CreateAuthenticatedClient(configured, "Role:list");
        client.DefaultRequestHeaders.Add("X-Tenant-Id", selectedTenant.ToString("D"));

        var tenantResponse = await client.GetAsync("/api/v1/role");
        var platformResponse = await client.GetAsync("/management/runtime");

        tenantResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        platformResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Diagnostic_endpoint_does_not_echo_sensitive_query_sentinels()
    {
        const string email = "diagnostic-g05@example.invalid";
        const string token = "diagnostic-g05-secret-token";
        using var configured = CreateGlobalAdministratorFactory(TestAuthHandler.DefaultTenantId);
        using var client = CreateAuthenticatedClient(configured, "Role:list");

        var response = await client.GetAsync(
            $"/management/runtime?email={Uri.EscapeDataString(email)}&access_token={Uri.EscapeDataString(token)}");
        var body = await response.Content.ReadAsStringAsync();

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        body.Should().NotContain(email).And.NotContain(token);
    }

    private Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> CreateGlobalAdministratorFactory(Guid tenantId) =>
        factory.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
        {
            services.RemoveAll<ICurrentUser>();
            services.AddScoped<ICurrentUser>(_ => new GlobalAdministratorCurrentUser(tenantId));
        }));

    private static HttpClient CreateAuthenticatedClient(
        Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> configured,
        params string[] permissions)
    {
        var client = configured.CreateClient();
        client.DefaultRequestHeaders.Add(
            TestAuthHandler.PermissionsHeader,
            permissions.Length == 0 ? "-" : string.Join(',', permissions));
        return client;
    }

    private sealed class GlobalAdministratorCurrentUser(Guid tenantId) : ICurrentUser
    {
        public Guid UserId => TestAuthHandler.DefaultUserId;
        public Guid? TenantId => tenantId;
        public IReadOnlyCollection<string> Departments => [];
        public IReadOnlyCollection<string> Roles => [];
        public IReadOnlyCollection<string> Permissions => [];
        public IReadOnlyList<string> GlobalRoles => ["PlatformAdmin"];
        public bool IsGlobalAdmin => true;
        public bool MfaEnabled => true;
        public bool IsAuthenticated => true;
    }

    private sealed class LoopbackRemoteAddressFilter : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use((context, continuation) =>
            {
                context.Connection.RemoteIpAddress = IPAddress.Loopback;
                return continuation();
            });
            next(app);
        };
    }
}

using System.Net;
using IFX.IntegrationTests.Fixtures;

namespace IFX.IntegrationTests.Endpoints;

public class HealthEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public HealthEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task HealthReady_ReturnsHealthStatus()
    {
        // Act
        var response = await _client.GetAsync("/health/ready");

        // Assert - Health endpoint returns OK for healthy or ServiceUnavailable for unhealthy
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.ServiceUnavailable);
    }

    [Fact]
    public async Task Health_ReturnsJsonResponse()
    {
        // Act
        var response = await _client.GetAsync("/health");

        // Assert
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.ServiceUnavailable);
        response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");
    }

    [Fact]
    public async Task Live_DoesNotDependOnExternalContributors()
    {
        var response = await _client.GetAsync("/health/live");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync()).Should().Contain("G04-LIVE");
    }

    [Fact]
    public async Task Startup_ReturnsStableReasonWithoutContributorDetails()
    {
        var response = await _client.GetAsync("/health/startup");
        var content = await response.Content.ReadAsStringAsync();

        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.ServiceUnavailable);
        content.Should().Contain("G04-");
        content.ToLowerInvariant().Should().NotContain("description");
    }

    [Fact]
    public async Task Details_RequiresAuthentication()
    {
        var response = await _client.GetAsync("/health/details");

        response.StatusCode.Should().BeOneOf(HttpStatusCode.Unauthorized, HttpStatusCode.Forbidden);
    }
}

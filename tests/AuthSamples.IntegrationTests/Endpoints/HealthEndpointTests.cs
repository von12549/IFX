using System.Net;
using AuthSamples.IntegrationTests.Fixtures;

namespace AuthSamples.IntegrationTests.Endpoints;

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
}

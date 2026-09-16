using System.Net;
using System.Net.Http.Json;
using IFX.IntegrationTests.Fixtures;
using IFX.Modules.IAM.Presentation.Identity.Requests;
using IFX.Tests.Common;

namespace IFX.IntegrationTests.Endpoints;

public class AuthEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public AuthEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Register_WithInvalidRequest_ReturnsErrorResponse()
    {
        // Arrange
        var request = new RegisterRequest
        {
            Email = "invalid-email",
            Password = "weak",
            Username = "ab",
            FirstName = "",
            LastName = "",
            BirthDate = DateTime.MinValue,
            PhoneNumber = "invalid"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", request);

        // Assert - Should return error status (BadRequest for validation or InternalServerError for unhandled)
        response.StatusCode.Should().BeOneOf(HttpStatusCode.BadRequest, HttpStatusCode.InternalServerError);
    }

    [Fact]
    public async Task Login_ReturnsGoneWithOAuthMigrationGuidance()
    {
        // Arrange
        var request = new LoginRequest
        {
            Email = "",
            Password = ""
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/auth/login", request);

        response.StatusCode.Should().Be(HttpStatusCode.Gone);
        var body = await response.Content.ReadAsStringAsync();
        body.Should().Contain("/api/v1/auth/oauth/authorize");
    }

    [Fact]
    public async Task Logout_WithoutAuthentication_ReturnsUnauthorized()
    {
        // Act
        var response = await _client.PostAsync("/api/v1/auth/logout", null);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Refresh_WithNonExistentUser_ReturnsNotFound()
    {
        // Arrange - using email that doesn't exist in test database
        var request = new RefreshTokenRequest
        {
            RefreshToken = "test-refresh-token",
            Email = "nonexistent@example.com"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/auth/refresh", request);

        // Assert - Returns 404 because user doesn't exist
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Revoke_WithInvalidToken_ReturnsErrorResponse()
    {
        // Arrange
        var request = new RevokeTokenRequest
        {
            RefreshToken = "invalid-token"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/auth/revoke", request);

        // Assert - AllowAnonymous endpoint returns error for invalid token (BadRequest or InternalServerError)
        response.StatusCode.Should().BeOneOf(HttpStatusCode.BadRequest, HttpStatusCode.InternalServerError);
    }
}

using System.Net;
using IFX.IntegrationTests.Fixtures;

namespace IFX.IntegrationTests.Endpoints;

/// <summary>
/// Tests the full permission enforcement pipeline:
/// unauthenticated → 401, authenticated without permission → 403, authenticated with permission → 200/404.
/// </summary>
public class PermissionEnforcementTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly CustomWebApplicationFactory _factory;

    public PermissionEnforcementTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    // ── User.Read ──────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAllUsers_WithoutToken_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/v1/usermanagement/users");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetAllUsers_WithTokenButNoPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient(); // no permissions
        var response = await client.GetAsync("/api/v1/usermanagement/users");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllUsers_WithWrongPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient("Role.Read");
        var response = await client.GetAsync("/api/v1/usermanagement/users");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllUsers_WithCorrectPermission_ReturnsSuccess()
    {
        var client = _factory.CreateAuthenticatedClient("User.Read");
        var response = await client.GetAsync("/api/v1/usermanagement/users");
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.NotFound);
    }

    // ── Role.Read ──────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAllRoles_WithoutToken_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/v1/role");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetAllRoles_WithTokenButNoPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/v1/role");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllRoles_WithWrongPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient("User.Read");
        var response = await client.GetAsync("/api/v1/role");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllRoles_WithCorrectPermission_ReturnsSuccess()
    {
        var client = _factory.CreateAuthenticatedClient("Role.Read");
        var response = await client.GetAsync("/api/v1/role");
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.NotFound);
    }

    // ── RoleGroup.Read ─────────────────────────────────────────────────────

    [Fact]
    public async Task GetAllRoleGroups_WithoutToken_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/v1/rolegroup");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetAllRoleGroups_WithTokenButNoPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/v1/rolegroup");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllRoleGroups_WithCorrectPermission_ReturnsSuccess()
    {
        var client = _factory.CreateAuthenticatedClient("RoleGroup.Read");
        var response = await client.GetAsync("/api/v1/rolegroup");
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.NotFound);
    }

    // ── Permission.Read ────────────────────────────────────────────────────

    [Fact]
    public async Task GetAllPermissions_WithoutToken_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/v1/permission");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetAllPermissions_WithTokenButNoPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/v1/permission");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllPermissions_WithCorrectPermission_ReturnsSuccess()
    {
        var client = _factory.CreateAuthenticatedClient("Permission.Read");
        var response = await client.GetAsync("/api/v1/permission");
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.NotFound);
    }

    // ── Idp.Read ───────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAllIdps_WithoutToken_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/v1/idp");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetAllIdps_WithTokenButNoPermission_ReturnsForbidden()
    {
        var client = _factory.CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/v1/idp");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetAllIdps_WithCorrectPermission_ReturnsSuccess()
    {
        var client = _factory.CreateAuthenticatedClient("Idp.Read");
        var response = await client.GetAsync("/api/v1/idp");
        response.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.NotFound);
    }
}

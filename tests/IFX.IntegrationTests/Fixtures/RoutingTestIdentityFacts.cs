using System.Security.Claims;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Infrastructure.Access;
using Microsoft.AspNetCore.Http;
namespace IFX.IntegrationTests.Fixtures;
// Explicit routing-test identity fixture. Never registered by production composition.
public sealed class RoutingTestIdentityFacts(IHttpContextAccessor http, HttpIdentityFacts actor) : IExecutionIdentityFacts
{
    public bool IsAuthenticated => actor.IsAuthenticated;
    public Guid UserId => actor.UserId;
    public bool MfaEnabled => actor.MfaEnabled;
    public Guid? PrimaryTenantId => Guid.TryParse(http.HttpContext?.User.FindFirst("tenant_id")?.Value, out var id) ? id : null;
    public bool IsTenantMember(Guid tenantId) => Values("tenant").Any(value => Guid.TryParse(value, out var id) && id == tenantId);
    public IReadOnlyCollection<string> Departments => Values("department");
    public IReadOnlyCollection<string> Roles => Values("role").Concat(Values(ClaimTypes.Role)).Distinct().ToArray();
    public IReadOnlyCollection<string> Permissions => Values("permission");
    private string[] Values(string type) => http.HttpContext?.User.FindAll(type).Select(c => c.Value).ToArray() ?? [];
}

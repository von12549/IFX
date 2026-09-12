using System.Security.Claims;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Http;

namespace IFX.Modules.IAM.Infrastructure.Access;

public sealed class HttpIdentityFacts(IHttpContextAccessor httpContextAccessor) : IExecutionIdentityFacts
{
    public ClaimsPrincipal? Principal => httpContextAccessor.HttpContext?.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;

    public Guid UserId => TryGetGuid("user_id");

    public IReadOnlyCollection<string> Departments => GetValues("department");

    public IReadOnlyCollection<string> Roles => Principal?
        .FindAll(ClaimTypes.Role)
        .Concat(Principal.FindAll("role"))
        .Select(claim => claim.Value)
        .Distinct(StringComparer.Ordinal)
        .ToArray() ?? [];

    public IReadOnlyCollection<string> Permissions => GetValues("permission");

    public bool MfaEnabled
    {
        get
        {
            var methods = GetValues("amr");
            return methods.Contains("mfa") || methods.Contains("otp") || methods.Contains("hwk");
        }
    }

    public Guid? PrimaryTenantId
    {
        get
        {
            var value = TryGetGuid("tenant_id");
            return value == Guid.Empty ? null : value;
        }
    }

    public bool IsTenantMember(Guid tenantId) => Principal?
        .FindAll("tenant")
        .Any(claim => Guid.TryParse(claim.Value, out var value) && value == tenantId) == true;

    private Guid TryGetGuid(string claimType)
    {
        var value = Principal?.FindFirst(claimType)?.Value;
        return Guid.TryParse(value, out var id) ? id : Guid.Empty;
    }

    private IReadOnlyCollection<string> GetValues(string claimType) => Principal?
        .FindAll(claimType)
        .Select(claim => claim.Value)
        .ToArray() ?? [];
}

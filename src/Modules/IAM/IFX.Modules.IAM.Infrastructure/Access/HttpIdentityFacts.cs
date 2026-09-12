using System.Security.Claims;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Http;
using IFX.Platform.Context.Contracts;

namespace IFX.Modules.IAM.Infrastructure.Access;

public sealed class HttpIdentityFacts(IHttpContextAccessor httpContextAccessor, IExecutionContextAccessor? execution = null) : IExecutionIdentityFacts
{
    public ClaimsPrincipal? Principal => httpContextAccessor.HttpContext?.User;

    public bool IsAuthenticated => httpContextAccessor.HttpContext is not null
        ? Principal?.Identity?.IsAuthenticated == true
        : execution?.HasCurrent == true && execution.Current.Provenance == ContextProvenance.Trusted &&
          execution.Current.Actor.Kind == ActorKind.User && Guid.TryParse(execution.Current.Actor.Id, out var id) && id != Guid.Empty;

    public Guid UserId => httpContextAccessor.HttpContext is not null ? TryGetGuid("user_id") :
        IsAuthenticated && Guid.TryParse(execution!.Current.Actor.Id, out var id) ? id : Guid.Empty;

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

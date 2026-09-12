using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Domain.Access;

namespace IFX.Modules.IAM.Infrastructure.Access;

public sealed class CurrentUser(VerifiedIdentityFacts facts) : ICurrentUser
{
    public bool IsAuthenticated => facts.IsAuthenticated;
    public Guid UserId => facts.UserId;
    public Guid? TenantId => facts.TenantId;
    public IReadOnlyCollection<string> Departments => facts.Departments;
    public IReadOnlyCollection<string> Roles => facts.Roles;
    public IReadOnlyCollection<string> Permissions => facts.Permissions;
    public bool MfaEnabled => facts.MfaEnabled;
    public IReadOnlyList<string> GlobalRoles => facts.GlobalRoles;
    public bool IsGlobalAdmin => GlobalRoles.Contains(GlobalRoleNames.PlatformAdmin);
}

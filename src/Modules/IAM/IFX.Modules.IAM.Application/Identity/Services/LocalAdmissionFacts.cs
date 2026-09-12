using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Domain.Users;
namespace IFX.Modules.IAM.Application.Identity.Services;

internal static class LocalAdmissionFacts
{
    // Login hints are limited to the validated primary membership. Runtime decisions reload the selected scope.
    public static UserAuthResult From(User user, bool provisioned = false)
    {
        var tenants = user.IsActive ? user.Tenants.Where(t => t.IsActive).Select(t => t.Id).ToList() : [];
        var primary = user.PrimaryTenantId is { } id && tenants.Contains(id) ? id : (Guid?)null;
        var roles = user.Roles.Where(r => r.TenantId == primary)
            .Concat(user.RoleGroups.Where(g => g.TenantId == primary).SelectMany(g => g.Roles).Where(r => r.TenantId == primary)).ToArray();
        return new UserAuthResult
        {
            UserId = user.Id, PrimaryTenantId = primary, TenantIds = tenants,
            PermissionNames = roles.SelectMany(r => r.Permissions).Select(p => p.Name).Distinct().ToList(),
            RoleNames = roles.Select(r => r.Name).Distinct().ToList(),
            DepartmentNames = user.Departments.Where(d => d.TenantId == primary).Select(d => d.Name).Distinct().ToList(),
            WasProvisioned = provisioned
        };
    }
}

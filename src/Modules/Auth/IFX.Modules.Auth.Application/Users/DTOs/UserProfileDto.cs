using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Authorization.Tenants.DTOs;
namespace IFX.Modules.Auth.Application.Users.DTOs;

public class UserProfileDto
{
    public Guid Id { get; init; }
    public string Email { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public string BirthDate { get; set; } = string.Empty;
    public string PhoneNumber { get; init; } = string.Empty;
    public bool EmailVerified { get; init; }
    public bool IsActive { get; init; }
    public string Issuer { get; init; } = string.Empty;
    public List<RoleDto> Roles { get; init; } = [];
    public List<RoleGroupDto> RoleGroups { get; init; } = [];
    public Guid? PrimaryTenantId { get; init; }
    public List<TenantDto> Tenants { get; init; } = [];
    public List<DepartmentDto> Departments { get; init; } = [];
    public List<string> GlobalRoles { get; init; } = [];
    public DateTime CreatedAt { get; init; }
}

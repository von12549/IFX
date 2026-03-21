using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public class AssignPermissionsToRoleRequest
{
    [Required]
    public List<Guid> PermissionIds { get; set; } = new();
}

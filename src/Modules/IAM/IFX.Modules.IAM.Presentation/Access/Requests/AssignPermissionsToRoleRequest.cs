using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Access.Requests;

public class AssignPermissionsToRoleRequest
{
    [Required]
    public List<Guid> PermissionIds { get; set; } = new();
}

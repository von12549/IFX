using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Access.Requests;

public class AssignRolesToRoleGroupRequest
{
    [Required]
    public List<Guid> RoleIds { get; set; } = new();
}

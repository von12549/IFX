using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public class AssignRolesToRoleGroupRequest
{
    [Required]
    public List<Guid> RoleIds { get; set; } = new();
}

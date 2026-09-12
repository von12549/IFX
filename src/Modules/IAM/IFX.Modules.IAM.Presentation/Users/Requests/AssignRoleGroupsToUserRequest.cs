using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Users.Requests;

public class AssignRoleGroupsToUserRequest
{
    [Required]
    public List<Guid> RoleGroupIds { get; set; } = new();
}

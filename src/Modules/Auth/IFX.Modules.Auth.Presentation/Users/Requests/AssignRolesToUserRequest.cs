using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Users.Requests;

public class AssignRolesToUserRequest
{
    [Required]
    public List<Guid> RoleIds { get; set; } = new();
}

using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Users.Requests;

public class AssignDepartmentToUserRequest
{
    [Required]
    public Guid DepartmentId { get; set; }
}

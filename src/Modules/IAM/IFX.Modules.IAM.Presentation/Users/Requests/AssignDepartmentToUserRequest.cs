using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Users.Requests;

public class AssignDepartmentToUserRequest
{
    [Required]
    public Guid DepartmentId { get; set; }
}

using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Users.Requests;

public class AssignTenantToUserRequest
{
    [Required]
    public Guid TenantId { get; set; }

    public bool SetAsPrimary { get; set; } = false;
}

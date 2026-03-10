using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Models.Requests.Role;

public class AddRoleRequest
{
    [Required]
    [MinLength(3)]
    [MaxLength(50)]
    public string RoleName { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string Description { get; set; } = string.Empty;
}

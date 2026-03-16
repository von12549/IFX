using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public class UpdateRoleRequest
{
    [Required]
    [MinLength(3)]
    [MaxLength(50)]
    public string RoleName { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string Description { get; set; } = string.Empty;
}

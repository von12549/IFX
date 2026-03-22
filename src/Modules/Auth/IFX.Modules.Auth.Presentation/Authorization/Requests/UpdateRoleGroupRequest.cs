using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public class UpdateRoleGroupRequest
{
    [Required]
    [MinLength(3)]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public Guid TenantId { get; set; }
}

using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Access.Requests;

public class UpdateRoleRequest
{
    [Required]
    [MinLength(3)]
    [MaxLength(50)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public Guid TenantId { get; set; }
}

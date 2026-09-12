using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Access.Requests;

public class UpdateTenantRequest
{
    [Required]
    public string Name { get; set; } = string.Empty;

    [Required]
    public string Description { get; set; } = string.Empty;
}

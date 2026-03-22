using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public class CreateTenantRequest
{
    [Required]
    public string Name { get; set; } = string.Empty;

    [Required]
    public string Description { get; set; } = string.Empty;
}

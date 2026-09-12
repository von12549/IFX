using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Identity.Requests;

public class LoginRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}

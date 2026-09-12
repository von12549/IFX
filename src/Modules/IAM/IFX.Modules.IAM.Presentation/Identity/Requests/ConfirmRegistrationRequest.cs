using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.IAM.Presentation.Identity.Requests;

public class ConfirmRegistrationRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string ConfirmationCode { get; set; } = string.Empty;
}

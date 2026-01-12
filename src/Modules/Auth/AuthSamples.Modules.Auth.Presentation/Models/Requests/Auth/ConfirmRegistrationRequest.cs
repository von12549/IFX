using System.ComponentModel.DataAnnotations;

namespace AuthSamples.Modules.Auth.Presentation.Models.Requests.Auth;

public class ConfirmRegistrationRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string ConfirmationCode { get; set; } = string.Empty;
}

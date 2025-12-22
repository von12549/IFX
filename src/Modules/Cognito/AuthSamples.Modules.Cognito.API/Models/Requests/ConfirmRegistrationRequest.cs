using System.ComponentModel.DataAnnotations;

namespace AuthSamples.Modules.Cognito.API.Models.Requests;

public class ConfirmRegistrationRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string ConfirmationCode { get; set; } = string.Empty;
}

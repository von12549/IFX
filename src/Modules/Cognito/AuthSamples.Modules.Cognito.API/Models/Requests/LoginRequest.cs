using System.ComponentModel.DataAnnotations;

namespace AuthSamples.Modules.Cognito.API.Models.Requests;

public class LoginRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}

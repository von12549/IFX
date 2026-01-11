using System.ComponentModel.DataAnnotations;

namespace AuthSamples.Modules.Cognito.API.Models;

public class RevokeTokenRequest
{
    [Required(ErrorMessage = "Refresh token is required")]
    public string RefreshToken { get; set; } = string.Empty;
}

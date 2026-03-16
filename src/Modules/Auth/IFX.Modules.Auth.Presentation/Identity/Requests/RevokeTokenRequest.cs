using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Models.Requests.Auth;

public class RevokeTokenRequest
{
    [Required(ErrorMessage = "Refresh token is required")]
    public string RefreshToken { get; set; } = string.Empty;
}

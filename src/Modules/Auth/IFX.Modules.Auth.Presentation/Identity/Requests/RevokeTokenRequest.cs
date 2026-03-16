using System.ComponentModel.DataAnnotations;

namespace IFX.Modules.Auth.Presentation.Identity.Requests;

public class RevokeTokenRequest
{
    [Required(ErrorMessage = "Refresh token is required")]
    public string RefreshToken { get; set; } = string.Empty;
}

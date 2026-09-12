namespace IFX.Modules.IAM.Infrastructure.IdentityProviders.Auth0;

public class Auth0Options
{
    public const string SectionName = "Auth0";

    public string Domain { get; set; } = string.Empty;
    public string ClientId { get; set; } = string.Empty;
    public string ClientSecret { get; set; } = string.Empty;
    public string Audience { get; set; } = string.Empty;
    public string CallbackUrl { get; set; } = string.Empty;
    public string LogoutCallbackUrl { get; set; } = string.Empty;
}

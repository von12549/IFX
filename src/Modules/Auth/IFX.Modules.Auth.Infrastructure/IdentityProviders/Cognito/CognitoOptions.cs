namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito;

public class CognitoOptions
{
    public const string SectionName = "CognitoSettings";

    public string UserPoolId { get; set; } = string.Empty;
    public string ClientId { get; set; } = string.Empty;
    public string ClientSecret { get; set; } = string.Empty;
    public string Region { get; set; } = "us-east-1";
    public string Authority { get; set; } = string.Empty;
}

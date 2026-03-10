namespace IFX.Tests.Common;

public static class TestConstants
{
    public const string ValidEmail = "test@example.com";
    public const string ValidPassword = "Test@12345";
    public const string IFXCognitoIssuer = "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P";
    public const string ValidSubject = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
    public const string ValidFirstName = "John";
    public const string ValidLastName = "Doe";
    public const string ValidDisplayName = "John Doe";
    public const string ValidPhoneNumber = "+61412345678";
    public const string ValidBirthDate = "1990-01-15";
    public const string ValidUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    public const string ValidIpAddress = "192.168.1.1";

    public static class Roles
    {
        public const string Admin = "Admin";
        public const string User = "User";
        public const string SsoUser = "SsoUser";
    }
}

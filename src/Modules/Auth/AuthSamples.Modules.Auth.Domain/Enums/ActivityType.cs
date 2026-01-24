namespace AuthSamples.Modules.Auth.Domain.Enums;

public enum ActivityType
{
    Registration = 0,
    RegistrationConfirmed = 1,
    Login = 2,
    Logout = 3,
    ProfileUpdate = 4,
    PasswordChange = 5,
    EmailVerification = 6,
    PhoneVerification = 7,
    EmailVerificationSent = 10,
    EmailVerified = 11,
    EmailVerificationFailed = 12,
    EmailChanged = 13
}

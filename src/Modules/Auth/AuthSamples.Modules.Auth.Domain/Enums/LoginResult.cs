namespace AuthSamples.Modules.Auth.Domain.Enums;

public enum LoginResult
{
    Success = 0,
    InvalidCredentials = 1,
    UserNotFound = 2,
    UserNotConfirmed = 3,
    TooManyAttempts = 4,
    AccountLocked = 5
}

using System.Security.Cryptography;
using System.Text;
using Amazon.CognitoIdentityProvider;
using Amazon.CognitoIdentityProvider.Model;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Infrastructure.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AuthSamples.Modules.Cognito.Infrastructure.Services;

public class CognitoService : ICognitoService
{
    private readonly IAmazonCognitoIdentityProvider _cognitoClient;
    private readonly CognitoSettings _settings;
    private readonly ILogger<CognitoService> _logger;

    public CognitoService(
        IAmazonCognitoIdentityProvider cognitoClient,
        IOptions<CognitoSettings> settings,
        ILogger<CognitoService> logger)
    {
        _cognitoClient = cognitoClient;
        _settings = settings.Value;
        _logger = logger;
    }

    private string ComputeSecretHash(string username)
    {
        var message = Encoding.UTF8.GetBytes(username + _settings.ClientId);
        var key = Encoding.UTF8.GetBytes(_settings.ClientSecret);

        using var hmac = new HMACSHA256(key);
        var hash = hmac.ComputeHash(message);
        return Convert.ToBase64String(hash);
    }

    public async Task<CognitoSignUpResult> SignUpAsync(
        string email,
        string password,
        string username,
        string firstName,
        string lastName,
        string birthDate,
        string phoneNumber)
    {
        try
        {
            var request = new SignUpRequest
            {
                ClientId = _settings.ClientId,
                SecretHash = ComputeSecretHash(email),
                Username = email, // Use email as username since Cognito User Pool is configured with email sign-in
                Password = password,
                UserAttributes = new List<AttributeType>
                {
                    new() { Name = "email", Value = email },
                    new() { Name = "preferred_username", Value = username }, // Store username as preferred_username
                    new() { Name = "given_name", Value = firstName },
                    new() { Name = "family_name", Value = lastName },
                    new() { Name = "birthdate", Value = birthDate },
                    new() { Name = "phone_number", Value = phoneNumber },
                }
            };

            var response = await _cognitoClient.SignUpAsync(request);

            _logger.LogInformation("User {Username} signed up successfully in Cognito", username);

            return new CognitoSignUpResult
            {
                Success = true,
                Subject = response.UserSub,
                UserConfirmed = response.UserConfirmed,
                ErrorMessage = null
            };
        }
        catch (UsernameExistsException)
        {
            _logger.LogWarning("Signup failed: Username {Username} already exists", username);
            return new CognitoSignUpResult
            {
                Success = false,
                ErrorMessage = "Username already exists"
            };
        }
        catch (InvalidPasswordException ex)
        {
            _logger.LogWarning("Signup failed: Invalid password for {Username}", username);
            return new CognitoSignUpResult
            {
                Success = false,
                ErrorMessage = $"Invalid password: {ex.Message}"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error signing up user {Username}", username);
            return new CognitoSignUpResult
            {
                Success = false,
                ErrorMessage = "An error occurred during sign up"
            };
        }
    }

    public async Task<bool> ConfirmSignUpAsync(string username, string confirmationCode)
    {
        try
        {
            var request = new ConfirmSignUpRequest
            {
                ClientId = _settings.ClientId,
                SecretHash = ComputeSecretHash(username),
                Username = username,
                ConfirmationCode = confirmationCode
            };

            await _cognitoClient.ConfirmSignUpAsync(request);

            _logger.LogInformation("User {Username} confirmed successfully in Cognito", username);
            return true;
        }
        catch (CodeMismatchException)
        {
            _logger.LogWarning("Confirmation failed: Invalid code for {Username}", username);
            return false;
        }
        catch (ExpiredCodeException)
        {
            _logger.LogWarning("Confirmation failed: Expired code for {Username}", username);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error confirming user {Username}", username);
            return false;
        }
    }

    public async Task<CognitoAuthResult> AuthenticateAsync(string username, string password)
    {
        try
        {
            var request = new InitiateAuthRequest
            {
                ClientId = _settings.ClientId,
                AuthFlow = AuthFlowType.USER_PASSWORD_AUTH,
                AuthParameters = new Dictionary<string, string>
                {
                    { "USERNAME", username },
                    { "PASSWORD", password },
                    { "SECRET_HASH", ComputeSecretHash(username) }
                }
            };

            var response = await _cognitoClient.InitiateAuthAsync(request);

            _logger.LogInformation("User {Username} authenticated successfully in Cognito", username);

            return new CognitoAuthResult
            {
                Success = true,
                AccessToken = response.AuthenticationResult.AccessToken,
                IdToken = response.AuthenticationResult.IdToken,
                RefreshToken = response.AuthenticationResult.RefreshToken,
                ExpiresIn = response.AuthenticationResult.ExpiresIn,
                ErrorMessage = null
            };
        }
        catch (UserNotConfirmedException)
        {
            _logger.LogWarning("Authentication failed: User {Username} not confirmed", username);
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "User account is not confirmed"
            };
        }
        catch (NotAuthorizedException)
        {
            _logger.LogWarning("Authentication failed: Invalid credentials for {Username}", username);
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "Invalid username or password"
            };
        }
        catch (UserNotFoundException)
        {
            _logger.LogWarning("Authentication failed: User {Username} not found", username);
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "Invalid username or password"
            };
        }
        catch (TooManyRequestsException)
        {
            _logger.LogWarning("Authentication failed: Too many requests for {Username}", username);
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "Too many login attempts. Please try again later."
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error authenticating user {Username}", username);
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "An error occurred during authentication"
            };
        }
    }

    public async Task<bool> SignOutAsync(string accessToken)
    {
        try
        {
            var request = new GlobalSignOutRequest
            {
                AccessToken = accessToken
            };

            await _cognitoClient.GlobalSignOutAsync(request);

            _logger.LogInformation("User signed out successfully from Cognito");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error signing out user from Cognito");
            return false;
        }
    }

    public async Task<CognitoUserInfo> GetUserAsync(string accessToken)
    {
        try
        {
            var request = new GetUserRequest
            {
                AccessToken = accessToken
            };

            var response = await _cognitoClient.GetUserAsync(request);

            var userInfo = new CognitoUserInfo
            {
                Subject = response.Username,
                Username = response.Username
            };

            foreach (var attribute in response.UserAttributes)
            {
                switch (attribute.Name)
                {
                    case "sub":
                        userInfo.Subject = attribute.Value;
                        break;
                    case "email":
                        userInfo.Email = attribute.Value;
                        break;
                    case "given_name":
                        userInfo.FirstName = attribute.Value;
                        break;
                    case "family_name":
                        userInfo.LastName = attribute.Value;
                        break;
                    case "phone_number":
                        userInfo.PhoneNumber = attribute.Value;
                        break;
                    case "email_verified":
                        userInfo.EmailVerified = attribute.Value == "true";
                        break;
                    case "phone_number_verified":
                        userInfo.PhoneNumberVerified = attribute.Value == "true";
                        break;
                }
            }

            return userInfo;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user from Cognito");
            throw;
        }
    }

    public async Task<CognitoAuthResult> RefreshTokenAsync(string refreshToken, string username)
    {
        try
        {
            var request = new AdminInitiateAuthRequest
            {
                UserPoolId = _settings.UserPoolId,
                ClientId = _settings.ClientId,
                AuthFlow = AuthFlowType.REFRESH_TOKEN_AUTH,
                AuthParameters = new Dictionary<string, string>
                {
                    { "REFRESH_TOKEN", refreshToken },
                    { "USERNAME", username },
                    { "SECRET_HASH", ComputeSecretHash(username) }
                }
            };

            var response = await _cognitoClient.AdminInitiateAuthAsync(request);

            _logger.LogInformation("Token refreshed successfully in Cognito");

            return new CognitoAuthResult
            {
                Success = true,
                AccessToken = response.AuthenticationResult.AccessToken,
                IdToken = response.AuthenticationResult.IdToken,
                RefreshToken = refreshToken, // Cognito doesn't return new refresh token
                ExpiresIn = response.AuthenticationResult.ExpiresIn,
                TokenType = response.AuthenticationResult.TokenType
            };
        }
        catch (NotAuthorizedException ex)
        {
            _logger.LogWarning(ex, "Refresh token is invalid or expired");
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "Refresh token is invalid or expired"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing token in Cognito");
            return new CognitoAuthResult
            {
                Success = false,
                ErrorMessage = "An error occurred while refreshing the token"
            };
        }
    }

    public async Task<bool> ResendConfirmationCodeAsync(string username)
    {
        try
        {
            var request = new ResendConfirmationCodeRequest
            {
                ClientId = _settings.ClientId,
                SecretHash = ComputeSecretHash(username),
                Username = username
            };

            await _cognitoClient.ResendConfirmationCodeAsync(request);

            _logger.LogInformation("Confirmation code resent for user {Username}", username);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resending confirmation code for {Username}", username);
            return false;
        }
    }

    public async Task<bool> RevokeTokenAsync(string refreshToken)
    {
        try
        {
            var request = new RevokeTokenRequest
            {
                ClientId = _settings.ClientId,
                ClientSecret = _settings.ClientSecret,
                Token = refreshToken
            };

            await _cognitoClient.RevokeTokenAsync(request);

            _logger.LogInformation("Refresh token revoked successfully");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error revoking refresh token");
            return false;
        }
    }
}

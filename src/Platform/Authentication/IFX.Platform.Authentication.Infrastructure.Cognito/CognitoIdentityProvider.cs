using System.Security.Cryptography;
using System.Text;
using Amazon.CognitoIdentityProvider;
using Amazon.CognitoIdentityProvider.Model;
using IFX.Platform.Authentication.Contracts.V1;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace IFX.Platform.Authentication.Infrastructure.Cognito;

public class CognitoIdentityProvider : IExternalAccountContract, ICredentialAuthenticationContract, ITokenLifecycleContract
{
    private readonly IAmazonCognitoIdentityProvider _cognitoClient;
    private readonly CognitoOptions _settings;
    private readonly ILogger<CognitoIdentityProvider> _logger;
    private readonly ITokenValidationContract _tokens;

    public CognitoIdentityProvider(
        IAmazonCognitoIdentityProvider cognitoClient,
        IOptions<CognitoOptions> settings,
        ILogger<CognitoIdentityProvider> logger,
        ITokenValidationContract tokens)
    {
        _cognitoClient = cognitoClient;
        _settings = settings.Value;
        _logger = logger;
        _tokens = tokens;
    }

    private string ComputeSecretHash(string username)
    {
        var message = Encoding.UTF8.GetBytes(username + _settings.ClientId);
        var key = Encoding.UTF8.GetBytes(_settings.ClientSecret);

        using var hmac = new HMACSHA256(key);
        var hash = hmac.ComputeHash(message);
        return Convert.ToBase64String(hash);
    }

    public async Task<ProviderSignUpResponse> SignUpAsync(
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

            _logger.LogInformation("External identity operation completed");

            return new ProviderSignUpResponse
            {
                Success = true,
                Subject = response.UserSub,
                UserConfirmed = response.UserConfirmed,
                ErrorMessage = null
            };
        }
        catch (UsernameExistsException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderSignUpResponse
            {
                Success = false,
                ErrorMessage = "Username already exists"
            };
        }
        catch (InvalidPasswordException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderSignUpResponse
            {
                Success = false,
                ErrorMessage = "Password requirements not met"
            };
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            return new ProviderSignUpResponse
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

            _logger.LogInformation("External identity operation completed");
            return true;
        }
        catch (CodeMismatchException)
        {
            _logger.LogWarning("External identity operation rejected");
            return false;
        }
        catch (ExpiredCodeException)
        {
            _logger.LogWarning("External identity operation rejected");
            return false;
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            return false;
        }
    }

    public async Task<ProviderTokenResponse> AuthenticateAsync(string username, string password)
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

            var identity = await ValidateIdentity(response.AuthenticationResult.IdToken);
            if (!identity.IsValid) return new() { ErrorMessage = identity.ReasonCode };

            _logger.LogInformation("External identity operation completed");

            return new ProviderTokenResponse
            {
                Success = true,
                AccessToken = response.AuthenticationResult.AccessToken,
                IdToken = response.AuthenticationResult.IdToken,
                RefreshToken = response.AuthenticationResult.RefreshToken,
                ExpiresIn = response.AuthenticationResult.ExpiresIn,
                Issuer = identity.Identity!.Issuer,
                Subject = identity.Identity.Subject,
                ErrorMessage = null
            };
        }
        catch (UserNotConfirmedException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderTokenResponse
            {
                Success = false,
                ErrorMessage = "User account is not confirmed"
            };
        }
        catch (NotAuthorizedException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderTokenResponse
            {
                Success = false,
                ErrorMessage = "Invalid username or password"
            };
        }
        catch (UserNotFoundException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderTokenResponse
            {
                Success = false,
                ErrorMessage = "Invalid username or password"
            };
        }
        catch (TooManyRequestsException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderTokenResponse
            {
                Success = false,
                ErrorMessage = "Too many login attempts. Please try again later."
            };
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            return new ProviderTokenResponse
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

            _logger.LogInformation("External identity operation completed");
            return true;
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            return false;
        }
    }

    public async Task<ProviderUserInfoDto> GetUserAsync(string accessToken)
    {
        try
        {
            var request = new GetUserRequest
            {
                AccessToken = accessToken
            };

            var response = await _cognitoClient.GetUserAsync(request);

            var userInfo = new ProviderUserInfoDto
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
                    case "birthdate":
                        userInfo.BirthDate = attribute.Value;
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
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            throw;
        }
    }

    public async Task<ProviderTokenResponse> RefreshTokenAsync(string refreshToken, string username)
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
            var identity = await ValidateIdentity(response.AuthenticationResult.IdToken);
            if (!identity.IsValid) return new() { ErrorMessage = identity.ReasonCode };

            _logger.LogInformation("External identity operation completed");

            return new ProviderTokenResponse
            {
                Success = true,
                AccessToken = response.AuthenticationResult.AccessToken,
                IdToken = response.AuthenticationResult.IdToken,
                RefreshToken = refreshToken, // Cognito doesn't return new refresh token
                Issuer = identity.Identity!.Issuer,
                Subject = identity.Identity.Subject,
                ExpiresIn = response.AuthenticationResult.ExpiresIn,
                TokenType = response.AuthenticationResult.TokenType
            };
        }
        catch (NotAuthorizedException)
        {
            _logger.LogWarning("External identity operation rejected");
            return new ProviderTokenResponse
            {
                Success = false,
                ErrorMessage = "Refresh token is invalid or expired"
            };
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            return new ProviderTokenResponse
            {
                Success = false,
                ErrorMessage = "An error occurred while refreshing the token"
            };
        }
    }

    private Task<TokenValidationResponse> ValidateIdentity(string idToken)
    {
        var issuer = string.IsNullOrWhiteSpace(_settings.Authority)
            ? $"https://cognito-idp.{_settings.Region}.amazonaws.com/{_settings.UserPoolId}" : _settings.Authority;
        return _tokens.ValidateAsync(idToken, new(issuer, issuer, [_settings.ClientId], ["RS256"], 60));
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

            _logger.LogInformation("External identity operation completed");
            return true;
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
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

            _logger.LogInformation("External identity operation completed");
            return true;
        }
        catch (Exception)
        {
            _logger.LogError("External identity operation failed");
            return false;
        }
    }
}

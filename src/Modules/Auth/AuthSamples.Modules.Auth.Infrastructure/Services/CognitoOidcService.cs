using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Infrastructure.Configuration;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AuthSamples.Modules.Auth.Infrastructure.Services;

public class CognitoOidcService : IOidcAuthService
{
    private readonly CognitoOidcSettings _settings;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IMemoryCache _cache;
    private readonly ILogger<CognitoOidcService> _logger;

    private const string StateCacheKeyPrefix = "oauth_state_";
    private const string HttpClientName = "CognitoOidc";

    public CognitoOidcService(
        IOptions<CognitoOidcSettings> settings,
        IHttpClientFactory httpClientFactory,
        IMemoryCache cache,
        ILogger<CognitoOidcService> logger)
    {
        _settings = settings.Value;
        _httpClientFactory = httpClientFactory;
        _cache = cache;
        _logger = logger;
    }

    public OidcAuthorizationUrl BuildAuthorizationUrl(string? redirectUri = null)
    {
        // Generate PKCE code verifier and challenge
        var codeVerifier = GenerateCodeVerifier();
        var codeChallenge = GenerateCodeChallenge(codeVerifier);

        // Generate state for CSRF protection
        var state = GenerateState();

        // Store state and code verifier in cache
        var cacheEntry = new OAuthStateEntry
        {
            State = state,
            CodeVerifier = codeVerifier,
            CreatedAt = DateTime.UtcNow
        };

        var cacheKey = $"{StateCacheKeyPrefix}{state}";
        _cache.Set(cacheKey, cacheEntry, TimeSpan.FromSeconds(_settings.StateCacheDurationSeconds));

        // Build authorization URL
        var callbackUrl = redirectUri ?? _settings.CallbackUrl;
        var scopes = string.Join(" ", _settings.Scopes);

        var queryParams = new Dictionary<string, string>
        {
            ["response_type"] = "code",
            ["client_id"] = _settings.ClientId,
            ["redirect_uri"] = callbackUrl,
            ["scope"] = scopes,
            ["state"] = state,
            ["code_challenge"] = codeChallenge,
            ["code_challenge_method"] = "S256"
        };

        var queryString = string.Join("&", queryParams.Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value)}"));
        var authUrl = $"{_settings.AuthorizationEndpoint}?{queryString}";

        _logger.LogInformation("Built authorization URL with state {State}", state);

        return new OidcAuthorizationUrl
        {
            Url = authUrl,
            State = state,
            CodeVerifier = codeVerifier
        };
    }

    public async Task<OidcTokenResult> ExchangeCodeForTokensAsync(string code, string state, string? redirectUri = null)
    {
        try
        {
            // Validate and retrieve state entry
            var cacheKey = $"{StateCacheKeyPrefix}{state}";
            if (!_cache.TryGetValue<OAuthStateEntry>(cacheKey, out var stateEntry))
            {
                _logger.LogWarning("Invalid or expired state parameter: {State}", state);
                return new OidcTokenResult
                {
                    Success = false,
                    Error = "invalid_state",
                    ErrorDescription = "State parameter is invalid or expired"
                };
            }

            // Remove state from cache (single use)
            _cache.Remove(cacheKey);

            var callbackUrl = redirectUri ?? _settings.CallbackUrl;

            // Build token request
            var tokenRequest = new Dictionary<string, string>
            {
                ["grant_type"] = "authorization_code",
                ["client_id"] = _settings.ClientId,
                ["code"] = code,
                ["redirect_uri"] = callbackUrl,
                ["code_verifier"] = stateEntry!.CodeVerifier
            };

            // Add client secret if configured
            if (!string.IsNullOrEmpty(_settings.ClientSecret))
            {
                tokenRequest["client_secret"] = _settings.ClientSecret;
            }

            var httpClient = _httpClientFactory.CreateClient(HttpClientName);
            var content = new FormUrlEncodedContent(tokenRequest);

            var response = await httpClient.PostAsync(_settings.TokenEndpoint, content);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Token exchange failed: {StatusCode} - {Response}",
                    response.StatusCode, responseContent);

                var errorResponse = JsonSerializer.Deserialize<TokenErrorResponse>(responseContent);
                return new OidcTokenResult
                {
                    Success = false,
                    Error = errorResponse?.Error ?? "token_exchange_failed",
                    ErrorDescription = errorResponse?.ErrorDescription ?? "Failed to exchange authorization code"
                };
            }

            var tokenResponse = JsonSerializer.Deserialize<TokenSuccessResponse>(responseContent);
            if (tokenResponse == null)
            {
                return new OidcTokenResult
                {
                    Success = false,
                    Error = "invalid_response",
                    ErrorDescription = "Invalid token response from authorization server"
                };
            }

            _logger.LogInformation("Successfully exchanged authorization code for tokens");

            return new OidcTokenResult
            {
                Success = true,
                AccessToken = tokenResponse.AccessToken,
                IdToken = tokenResponse.IdToken,
                RefreshToken = tokenResponse.RefreshToken,
                ExpiresIn = tokenResponse.ExpiresIn,
                TokenType = tokenResponse.TokenType ?? "Bearer"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error exchanging authorization code for tokens");
            return new OidcTokenResult
            {
                Success = false,
                Error = "exchange_error",
                ErrorDescription = "An error occurred during token exchange"
            };
        }
    }

    public async Task<OidcUserInfo> GetUserInfoAsync(string accessToken)
    {
        try
        {
            var httpClient = _httpClientFactory.CreateClient(HttpClientName);
            httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            var response = await httpClient.GetAsync(_settings.UserInfoEndpoint);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("UserInfo request failed: {StatusCode} - {Response}",
                    response.StatusCode, responseContent);
                throw new InvalidOperationException($"Failed to get user info: {response.StatusCode}");
            }

            var userInfoResponse = JsonSerializer.Deserialize<UserInfoResponse>(responseContent);
            if (userInfoResponse == null)
            {
                throw new InvalidOperationException("Invalid userinfo response");
            }

            _logger.LogInformation("Successfully retrieved user info for subject {Subject}", userInfoResponse.Sub);

            return new OidcUserInfo
            {
                Subject = userInfoResponse.Sub ?? string.Empty,
                Email = userInfoResponse.Email,
                EmailVerified = userInfoResponse.EmailVerified,
                Name = userInfoResponse.Name,
                GivenName = userInfoResponse.GivenName,
                FamilyName = userInfoResponse.FamilyName,
                PreferredUsername = userInfoResponse.PreferredUsername,
                PhoneNumber = userInfoResponse.PhoneNumber,
                PhoneNumberVerified = userInfoResponse.PhoneNumberVerified
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user info");
            throw;
        }
    }

    public string BuildLogoutUrl(string? idTokenHint = null, string? postLogoutRedirectUri = null)
    {
        var logoutUri = postLogoutRedirectUri ?? _settings.LogoutCallbackUrl;

        var queryParams = new Dictionary<string, string>
        {
            ["client_id"] = _settings.ClientId,
            ["logout_uri"] = logoutUri
        };

        var queryString = string.Join("&", queryParams.Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value)}"));
        return $"{_settings.LogoutEndpoint}?{queryString}";
    }

    public bool ValidateState(string state)
    {
        var cacheKey = $"{StateCacheKeyPrefix}{state}";
        return _cache.TryGetValue<OAuthStateEntry>(cacheKey, out _);
    }

    #region PKCE Helpers

    private static string GenerateCodeVerifier()
    {
        var bytes = new byte[32];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(bytes);
        return Base64UrlEncode(bytes);
    }

    private static string GenerateCodeChallenge(string codeVerifier)
    {
        using var sha256 = SHA256.Create();
        var bytes = Encoding.ASCII.GetBytes(codeVerifier);
        var hash = sha256.ComputeHash(bytes);
        return Base64UrlEncode(hash);
    }

    private static string GenerateState()
    {
        var bytes = new byte[32];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(bytes);
        return Base64UrlEncode(bytes);
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    #endregion

    #region Response Models

    private class OAuthStateEntry
    {
        public string State { get; set; } = string.Empty;
        public string CodeVerifier { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }

    private class TokenSuccessResponse
    {
        [System.Text.Json.Serialization.JsonPropertyName("access_token")]
        public string? AccessToken { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("id_token")]
        public string? IdToken { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("refresh_token")]
        public string? RefreshToken { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("expires_in")]
        public int ExpiresIn { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("token_type")]
        public string? TokenType { get; set; }
    }

    private class TokenErrorResponse
    {
        [System.Text.Json.Serialization.JsonPropertyName("error")]
        public string? Error { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("error_description")]
        public string? ErrorDescription { get; set; }
    }

    private class UserInfoResponse
    {
        [System.Text.Json.Serialization.JsonPropertyName("sub")]
        public string? Sub { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("email")]
        public string? Email { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("email_verified")]
        public bool EmailVerified { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("name")]
        public string? Name { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("given_name")]
        public string? GivenName { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("family_name")]
        public string? FamilyName { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("preferred_username")]
        public string? PreferredUsername { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("phone_number")]
        public string? PhoneNumber { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("phone_number_verified")]
        public bool PhoneNumberVerified { get; set; }
    }

    #endregion
}

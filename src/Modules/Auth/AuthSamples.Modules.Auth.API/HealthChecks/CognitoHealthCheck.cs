using Amazon.CognitoIdentityProvider;
using Amazon.CognitoIdentityProvider.Model;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace AuthSamples.Modules.Auth.API.HealthChecks;

public class CognitoHealthCheck : IHealthCheck
{
    private readonly IAmazonCognitoIdentityProvider _cognitoClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<CognitoHealthCheck> _logger;

    public CognitoHealthCheck(
        IAmazonCognitoIdentityProvider cognitoClient,
        IConfiguration configuration,
        ILogger<CognitoHealthCheck> logger)
    {
        _cognitoClient = cognitoClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var userPoolId = _configuration["CognitoSettings:UserPoolId"];

            if (string.IsNullOrWhiteSpace(userPoolId))
            {
                return HealthCheckResult.Unhealthy(
                    "AWS Cognito User Pool ID is not configured");
            }

            // Attempt to describe the user pool (lightweight operation)
            var request = new DescribeUserPoolRequest
            {
                UserPoolId = userPoolId
            };

            var response = await _cognitoClient.DescribeUserPoolAsync(request, cancellationToken);

            if (response.UserPool != null)
            {
                var data = new Dictionary<string, object>
                {
                    { "userPoolId", userPoolId },
                    { "userPoolName", response.UserPool.Name ?? "Unknown" },
                    { "creationDate", response.UserPool.CreationDate }
                };

                return HealthCheckResult.Healthy(
                    "AWS Cognito is accessible and User Pool is active",
                    data);
            }

            return HealthCheckResult.Degraded("AWS Cognito responded but User Pool data is unavailable");
        }
        catch (UserPoolTaggingException ex)
        {
            _logger.LogWarning(ex, "AWS Cognito User Pool access issue");
            return HealthCheckResult.Degraded(
                "AWS Cognito is accessible but there are permission issues",
                ex);
        }
        catch (ResourceNotFoundException ex)
        {
            _logger.LogError(ex, "AWS Cognito User Pool not found");
            return HealthCheckResult.Unhealthy(
                "AWS Cognito User Pool not found",
                ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AWS Cognito health check failed");
            return HealthCheckResult.Unhealthy(
                "AWS Cognito is not accessible",
                ex);
        }
    }
}

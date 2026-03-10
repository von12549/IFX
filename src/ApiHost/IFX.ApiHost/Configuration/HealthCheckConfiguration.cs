using IFX.ApiHost.HealthChecks;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Text.Json;

namespace IFX.ApiHost.Configuration;

public static class HealthCheckConfiguration
{
    /// <summary>
    /// Configures health checks for SQL Server and AWS Cognito
    /// </summary>
    public static IServiceCollection AddAuthHealthChecks(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("AuthDatabase");

        services.AddHealthChecks()
            .AddSqlServer(
                connectionString: connectionString!,
                healthQuery: "SELECT 1;",
                name: "SQL Server",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "database", "sqlserver" })
            .AddCheck<CognitoHealthCheck>(
                name: "AWS Cognito",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "aws", "cognito", "authentication" });

        return services;
    }

    /// <summary>
    /// Maps health check endpoints with custom response writers
    /// </summary>
    public static IEndpointRouteBuilder MapAuthHealthCheckEndpoints(this IEndpointRouteBuilder builder)
    {
        // Detailed health check endpoint with JSON response
        builder.MapHealthChecks("/health", new HealthCheckOptions
        {
            Predicate = _ => true,
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "application/json";
                var result = JsonSerializer.Serialize(new
                {
                    status = report.Status.ToString(),
                    timestamp = DateTime.UtcNow,
                    totalDuration = report.TotalDuration.TotalMilliseconds,
                    checks = report.Entries.Select(e => new
                    {
                        name = e.Key,
                        status = e.Value.Status.ToString(),
                        description = e.Value.Description,
                        duration = e.Value.Duration.TotalMilliseconds,
                        tags = e.Value.Tags
                    })
                }, new JsonSerializerOptions
                {
                    WriteIndented = true
                });
                await context.Response.WriteAsync(result);
            }
        });

        // Simple health check endpoint for Kubernetes readiness probes
        builder.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = _ => true,
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "text/plain";
                await context.Response.WriteAsync(report.Status.ToString());
            }
        });

        return builder;
    }
}

using IFX.ApiHost.HealthChecks;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
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
        var releaseManifest = ReleaseSchemaManifest.Load(
            Path.Combine(AppContext.BaseDirectory, "release-manifest.json"));
        var manifestErrors = SchemaCompatibilityPlanner.ValidateManifest(releaseManifest);
        if (manifestErrors.Count > 0)
        {
            throw new InvalidOperationException(
                $"Release schema manifest is invalid: {string.Join(" ", manifestErrors)}");
        }

        services.AddSingleton(releaseManifest);

        services.AddHealthChecks()
            .AddSqlServer(
                connectionString: connectionString!,
                healthQuery: "SELECT 1;",
                name: "SQL Server",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "database", "sqlserver", "readiness-critical", "api", "worker", "all" })
            .AddCheck<CognitoHealthCheck>(
                name: "AWS Cognito",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "aws", "cognito", "authentication", "capability-critical", "api", "all" })
            .AddCheck<DatabaseSchemaCompatibilityHealthCheck>(
                name: "Database schema compatibility",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "database", "schema", "readiness", "readiness-critical", "api", "worker", "all" });

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

        // Database-only release gate. External dependencies such as Cognito must not mask schema readiness.
        builder.MapHealthChecks("/health/database", new HealthCheckOptions
        {
            Predicate = registration => registration.Tags.Contains("database"),
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "text/plain";
                await context.Response.WriteAsync(report.Status.ToString());
            }
        });

        // Aggregate readiness for the complete application and its external dependencies.
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

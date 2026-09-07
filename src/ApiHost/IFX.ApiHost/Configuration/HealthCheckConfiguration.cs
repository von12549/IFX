using IFX.ApiHost.HealthChecks;
using IFX.ApiHost.Runtime;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.ApiHost.Configuration;

public static class HealthCheckConfiguration
{
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
        var healthChecks = services.AddHealthChecks();
        foreach (var module in releaseManifest.Modules)
        {
            healthChecks.AddSqlServer(
                connectionString: configuration.GetConnectionString(module.RuntimeConnectionKey) ?? connectionString!,
                healthQuery: "SELECT 1;",
                name: $"{module.ModuleName} SQL",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "database", "sqlserver", "readiness-critical", "api", "worker", "all", module.ModuleName.ToLowerInvariant() });
        }

        healthChecks
            .AddCheck<CognitoHealthCheck>(
                name: "AWS Cognito",
                failureStatus: HealthStatus.Degraded,
                tags: new[] { "aws", "cognito", "authentication", "capability-critical", "api", "all" })
            .AddCheck<DatabaseSchemaCompatibilityHealthCheck>(
                name: "Database schema compatibility",
                failureStatus: HealthStatus.Unhealthy,
                tags: new[] { "database", "schema", "readiness", "readiness-critical", "api", "worker", "all" });

        return services;
    }

    public static IEndpointRouteBuilder MapAuthHealthCheckEndpoints(this IEndpointRouteBuilder builder)
    {
        builder.MapGet("/health/live", (RuntimeLifecycle lifecycle) =>
        {
            var snapshot = lifecycle.Snapshot;
            var failed = snapshot.State == RuntimeLifecycleState.Terminated ||
                snapshot.ReasonCode == "G04-WORKER-CRITICAL-LOOP-FAILED";
            return Probe(failed ? 503 : 200, failed ? snapshot.ReasonCode : "G04-LIVE");
        });

        builder.MapGet("/health/startup", (RuntimeLifecycle lifecycle) =>
        {
            var snapshot = lifecycle.Snapshot;
            var started = snapshot.State != RuntimeLifecycleState.Starting;
            return Probe(started ? 200 : 503, started ? "G04-STARTED" : "G04-STARTING");
        });

        builder.MapGet("/health/ready", (RuntimeLifecycle lifecycle, HealthSnapshotStore store) =>
        {
            var runtime = lifecycle.Snapshot;
            var ready = runtime.State is RuntimeLifecycleState.Ready or RuntimeLifecycleState.Degraded;
            var reason = ready ? store.Snapshot.ReasonCode : runtime.ReasonCode;
            return Probe(ready ? 200 : 503, reason);
        });

        // Compatibility aggregate: intentionally contains no contributor detail.
        builder.MapGet("/health", (RuntimeLifecycle lifecycle) =>
        {
            var snapshot = lifecycle.Snapshot;
            var ready = snapshot.State is RuntimeLifecycleState.Ready or RuntimeLifecycleState.Degraded;
            return Probe(ready ? 200 : 503, snapshot.ReasonCode);
        });

        // Gate 02 database-only release gate.
        builder.MapHealthChecks("/health/database", new HealthCheckOptions
        {
            Predicate = registration => registration.Tags.Contains("database")
        });

        builder.MapGet("/health/details", (
            RuntimeLifecycle lifecycle,
            HealthSnapshotStore store,
            RuntimeProfile profile,
            RuntimeInstanceIdentity instance,
            ReleaseRuntimeManifest release) =>
        {
            var runtime = lifecycle.Snapshot;
            var health = store.Snapshot;
            return Results.Json(new
            {
                status = health.Status,
                reason = runtime.State is RuntimeLifecycleState.Ready or RuntimeLifecycleState.Degraded
                    ? health.ReasonCode
                    : runtime.ReasonCode,
                release = release.ReleaseId,
                role = profile.RoleName,
                instance = instance.Value,
                lifecycle = runtime.State.ToString(),
                freshness = new { lastChecked = health.LastChecked },
                contributors = health.Contributors.Select(item => new
                {
                    item.Name,
                    item.Status,
                    reason = item.ReasonCode,
                    item.LastChecked,
                    item.LastSucceeded,
                    item.DurationMilliseconds
                })
            });
        }).RequireAuthorization();

        return builder;
    }

    private static IResult Probe(int statusCode, string reasonCode) =>
        Results.Json(new { status = statusCode == 200 ? "Healthy" : "Unhealthy", reason = reasonCode }, statusCode: statusCode);
}

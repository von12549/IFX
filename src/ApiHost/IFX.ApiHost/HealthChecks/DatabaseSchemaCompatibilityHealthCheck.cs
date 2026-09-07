using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.ApiHost.HealthChecks;

public sealed class DatabaseSchemaCompatibilityHealthCheck(
    IConfiguration configuration,
    ReleaseSchemaManifest manifest) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var results = new List<ModuleSchemaCompatibility>();
        try
        {
            foreach (var requirement in manifest.Modules)
            {
                var connectionString = configuration.GetConnectionString(requirement.RuntimeConnectionKey);
                if (string.IsNullOrWhiteSpace(connectionString))
                {
                    return HealthCheckResult.Unhealthy(
                        $"Database schema is not ready ({requirement.ModuleName}: configuration-missing).");
                }

                await using var connection = new SqlConnection(connectionString);
                await connection.OpenAsync(cancellationToken);
                await using var command = connection.CreateCommand();
                command.CommandText = $"SELECT [MigrationId] FROM {Quote(requirement.Schema)}.{Quote(requirement.HistoryTable)} ORDER BY [MigrationId];";
                var applied = new List<string>();
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    applied.Add(reader.GetString(0));
                }
                results.Add(SchemaCompatibilityPlanner.Evaluate(requirement, applied));
            }
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            return HealthCheckResult.Unhealthy("Database schema compatibility check could not complete.");
        }

        var incompatible = results.Where(result => !result.IsCompatible).ToArray();
        if (incompatible.Length > 0)
        {
            var reasons = string.Join(", ", incompatible.Select(result => $"{result.ModuleName}:{result.Code}"));
            return HealthCheckResult.Unhealthy($"Database schema is not ready ({reasons}).");
        }

        return HealthCheckResult.Healthy("Database schema is compatible with this release.");
    }

    private static string Quote(string identifier) => $"[{identifier.Replace("]", "]]", StringComparison.Ordinal)}]";
}

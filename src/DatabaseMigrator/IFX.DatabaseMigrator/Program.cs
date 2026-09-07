using System.Text.Json;
using IFX.BuildingBlocks.EntityFrameworkCore.Configuration;
using IFX.DatabaseMigrator;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

const int success = 0;
const int configurationFailure = 2;
const int preflightFailure = 10;
const int lockFailure = 20;
const int migrationFailure = 30;
const int validationFailure = 40;

MigratorOptions options;
try
{
    options = MigratorOptions.Parse(args);
}
catch (Exception exception)
{
    Console.Error.WriteLine(exception.Message);
    return configurationFailure;
}

var contexts = new Dictionary<string, DbContext>(StringComparer.Ordinal);
try
{
    var configuration = new ConfigurationBuilder()
        .AddJsonFile(Path.Combine(AppContext.BaseDirectory, "appsettings.json"), optional: true)
        .AddEnvironmentVariables()
        .Build();
    var manifestPath = Path.Combine(AppContext.BaseDirectory, "migration-manifest.json");
    var manifest = MigrationManifest.Load(manifestPath);
    var connectionStrings = new Dictionary<string, string>(StringComparer.Ordinal);
    foreach (var runtime in ModuleRuntime.All)
    {
        var connectionString = RequiredConnectionString.Get(configuration, runtime.ConnectionKey);
        connectionStrings[runtime.ModuleName] = connectionString;
        contexts[runtime.ModuleName] = runtime.CreateContext(connectionString);
    }

    var runner = new DatabaseMigratorRunner(manifest, options, connectionStrings, contexts);
    var report = await runner.RunAsync(CancellationToken.None);
    var json = JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true });
    var reportDirectory = Path.GetDirectoryName(options.ReportPath);
    if (!string.IsNullOrWhiteSpace(reportDirectory))
    {
        Directory.CreateDirectory(reportDirectory);
    }
    await File.WriteAllTextAsync(options.ReportPath, json + Environment.NewLine);
    Console.WriteLine(json);

    if (report.Result == "succeeded")
    {
        return success;
    }
    if (report.FailurePoint == "database-lock")
    {
        return lockFailure;
    }
    if (report.FailurePoint is "database-validation" or "post-validation")
    {
        return validationFailure;
    }
    if (report.FailurePoint?.StartsWith("module:", StringComparison.Ordinal) == true)
    {
        return migrationFailure;
    }
    return preflightFailure;
}
catch (Exception exception)
{
    Console.Error.WriteLine(exception.Message);
    return configurationFailure;
}
finally
{
    foreach (var context in contexts.Values)
    {
        await context.DisposeAsync();
    }
}

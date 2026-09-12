using System.Diagnostics;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace IFX.DatabaseMigrator;

public sealed class DatabaseMigratorRunner(
    MigrationManifest manifest,
    MigratorOptions options,
    IReadOnlyDictionary<string, string> connectionStrings,
    IReadOnlyDictionary<string, DbContext> contexts,
    Func<ModuleRuntime, DbContext, CancellationToken, Task>? migrateModule = null)
{
    private readonly IReadOnlyList<ModuleRuntime> _runtimes = ModuleRuntime.All.OrderBy(module => module.Order).ToArray();

    public async Task<MigratorReport> RunAsync(CancellationToken cancellationToken)
    {
        var started = DateTimeOffset.UtcNow;
        var moduleReports = new List<ModuleMigrationReport>();
        HistoryBootstrapPlan? bootstrapPlan = null;
        AuthLegacyAdoptionPlan? adoptionPlan = null;
        string? failurePoint = null;
        try
        {
            failurePoint = "manifest-validation";
            var errors = MigrationManifestValidator.Validate(manifest, _runtimes, contexts)
                .Concat(ValidatePhysicalDatabase(connectionStrings))
                .ToArray();
            if (errors.Length > 0)
            {
                return Failed(started, failurePoint, errors, bootstrapPlan, adoptionPlan, moduleReports);
            }

            if (options.Mode == MigratorMode.Validate)
            {
                failurePoint = "database-validation";
                moduleReports.AddRange(await ValidateModulesAsync(cancellationToken));
                var validationErrors = moduleReports
                    .Where(report => report.Result != "valid")
                    .Select(report => $"{report.Module} has pending migrations.")
                    .ToArray();
                return validationErrors.Length == 0
                    ? Succeeded(started, bootstrapPlan, adoptionPlan, moduleReports)
                    : Failed(started, failurePoint, validationErrors, bootstrapPlan, adoptionPlan, moduleReports);
            }

            failurePoint = "history-preflight";
            bootstrapPlan = await BootstrapAsync(dryRun: true, acquireLock: false, cancellationToken);
            var needsAuthAdoption = bootstrapPlan.Errors.Any(IsAuthAdoptionBlocker);
            if (needsAuthAdoption)
            {
                failurePoint = "auth-legacy-adoption";
                adoptionPlan = await AdoptAuthAsync(
                    dryRun: options.Mode != MigratorMode.Apply,
                    acquireLock: false,
                    cancellationToken);
            }

            if (options.Mode is MigratorMode.Preflight or MigratorMode.DryRun)
            {
                var remainingErrors = bootstrapPlan.Errors
                    .Where(error => !needsAuthAdoption || !IsAuthAdoptionBlocker(error))
                    .Concat(adoptionPlan is null ? [] : adoptionPlan.Errors)
                    .ToArray();
                return remainingErrors.Length == 0
                    ? Succeeded(started, bootstrapPlan, adoptionPlan, moduleReports)
                    : Failed(started, failurePoint, remainingErrors, bootstrapPlan, adoptionPlan, moduleReports);
            }

            failurePoint = "database-lock";
            await using var migrationLock = await DatabaseMigrationLock.AcquireAsync(
                connectionStrings["Auth"],
                TimeSpan.FromSeconds(60),
                cancellationToken);

            bootstrapPlan = await BootstrapAsync(dryRun: true, acquireLock: false, cancellationToken);
            needsAuthAdoption = bootstrapPlan.Errors.Any(IsAuthAdoptionBlocker);
            if (needsAuthAdoption)
            {
                failurePoint = "auth-legacy-adoption";
                adoptionPlan = await AdoptAuthAsync(false, false, cancellationToken);
                bootstrapPlan = await BootstrapAsync(true, false, cancellationToken);
            }

            if (!bootstrapPlan.CanApply)
            {
                return Failed(started, "history-preflight", bootstrapPlan.Errors, bootstrapPlan, adoptionPlan, moduleReports);
            }

            failurePoint = "history-bootstrap";
            await BootstrapAsync(dryRun: false, acquireLock: false, cancellationToken);

            foreach (var runtime in _runtimes)
            {
                failurePoint = $"module:{runtime.ModuleName}";
                moduleReports.Add(await MigrateModuleAsync(runtime, cancellationToken));
            }

            failurePoint = "post-validation";
            var validated = await ValidateModulesAsync(cancellationToken);
            var invalid = validated.Where(report => report.Result != "valid").ToArray();
            if (invalid.Length > 0)
            {
                return Failed(
                    started,
                    failurePoint,
                    invalid.Select(report => $"{report.Module} has pending migrations.").ToArray(),
                    bootstrapPlan,
                    adoptionPlan,
                    moduleReports);
            }

            return Succeeded(started, bootstrapPlan, adoptionPlan, moduleReports);
        }
        catch (Exception exception)
        {
            return Failed(
                started,
                failurePoint ?? "startup",
                [Sanitize(exception)],
                bootstrapPlan,
                adoptionPlan,
                moduleReports);
        }
    }

    private async Task<HistoryBootstrapPlan> BootstrapAsync(
        bool dryRun,
        bool acquireLock,
        CancellationToken cancellationToken)
    {
        var catalogs = _runtimes.Select(runtime => runtime.CreateCatalog(contexts[runtime.ModuleName])).ToArray();
        await using var connection = new SqlConnection(connectionStrings["Auth"]);
        var result = await new SqlServerHistoryBootstrapper().RunAsync(
            connection,
            catalogs,
            dryRun,
            acquireLock,
            cancellationToken);
        return result.Before;
    }

    private async Task<AuthLegacyAdoptionPlan> AdoptAuthAsync(
        bool dryRun,
        bool acquireLock,
        CancellationToken cancellationToken)
    {
        var auth = (IfxDbContext)contexts["Auth"];
        var authIds = _runtimes.Single(runtime => runtime.ModuleName == "Auth")
            .CurrentMigrationRows(auth)
            .Select(row => row.MigrationId)
            .ToArray();
        var foreignIds = _runtimes.Where(runtime => runtime.ModuleName != "Auth")
            .SelectMany(runtime => runtime.CurrentMigrationRows(contexts[runtime.ModuleName]))
            .Select(row => row.MigrationId)
            .ToArray();
        var verifier = new AuthSchemaFingerprintVerifier(auth);
        await using var connection = new SqlConnection(connectionStrings["Auth"]);
        return await new SqlServerAuthLegacyAdopter().RunAsync(
            connection,
            authIds,
            foreignIds,
            AuthLegacyMigrationManifest.GetCanonicalProductVersion(auth),
            verifier.VerifyAsync,
            options.ExplicitAuthAdoption,
            dryRun,
            acquireLock,
            cancellationToken);
    }

    private async Task<ModuleMigrationReport> MigrateModuleAsync(
        ModuleRuntime runtime,
        CancellationToken cancellationToken)
    {
        var context = contexts[runtime.ModuleName];
        var before = (await context.Database.GetAppliedMigrationsAsync(cancellationToken)).ToArray();
        var pending = (await context.Database.GetPendingMigrationsAsync(cancellationToken)).ToArray();
        var stopwatch = Stopwatch.StartNew();
        if (migrateModule is null)
        {
            await context.Database.MigrateAsync(cancellationToken);
        }
        else
        {
            await migrateModule(runtime, context, cancellationToken);
        }
        stopwatch.Stop();
        var after = (await context.Database.GetAppliedMigrationsAsync(cancellationToken)).ToArray();
        return new ModuleMigrationReport(
            runtime.ModuleName,
            runtime.Schema,
            $"{runtime.Schema}.{runtime.HistoryTable}",
            before.LastOrDefault(),
            after.LastOrDefault(),
            pending,
            after.Except(before, StringComparer.Ordinal).ToArray(),
            stopwatch.ElapsedMilliseconds,
            "applied");
    }

    private async Task<IReadOnlyList<ModuleMigrationReport>> ValidateModulesAsync(
        CancellationToken cancellationToken)
    {
        var reports = new List<ModuleMigrationReport>();
        foreach (var runtime in _runtimes)
        {
            var context = contexts[runtime.ModuleName];
            var applied = (await context.Database.GetAppliedMigrationsAsync(cancellationToken)).ToArray();
            var pending = (await context.Database.GetPendingMigrationsAsync(cancellationToken)).ToArray();
            var owned = runtime.CurrentMigrationRows(context).Select(row => row.MigrationId).ToHashSet(StringComparer.Ordinal);
            var foreign = applied.Where(id => !owned.Contains(id)).ToArray();
            reports.Add(new ModuleMigrationReport(
                runtime.ModuleName,
                runtime.Schema,
                $"{runtime.Schema}.{runtime.HistoryTable}",
                applied.LastOrDefault(),
                applied.LastOrDefault(),
                pending,
                [],
                0,
                pending.Length == 0 && foreign.Length == 0 ? "valid" : "invalid"));
        }
        return reports;
    }

    private static IEnumerable<string> ValidatePhysicalDatabase(IReadOnlyDictionary<string, string> values)
    {
        var identities = values.Select(pair =>
        {
            var builder = new SqlConnectionStringBuilder(pair.Value);
            return (pair.Key, Identity: $"{builder.DataSource}|{builder.InitialCatalog}");
        }).ToArray();
        if (identities.Select(item => item.Identity).Distinct(StringComparer.OrdinalIgnoreCase).Count() != 1)
        {
            yield return "All module migration connections must target the same physical database for this manifest.";
        }
    }

    private MigratorReport Succeeded(
        DateTimeOffset started,
        HistoryBootstrapPlan? bootstrap,
        AuthLegacyAdoptionPlan? adoption,
        IReadOnlyList<ModuleMigrationReport> modules) =>
        new(options.Mode.ToString(), started, DateTimeOffset.UtcNow, "succeeded", null, [], bootstrap, adoption, modules);

    private MigratorReport Failed(
        DateTimeOffset started,
        string failurePoint,
        IReadOnlyList<string> errors,
        HistoryBootstrapPlan? bootstrap,
        AuthLegacyAdoptionPlan? adoption,
        IReadOnlyList<ModuleMigrationReport> modules) =>
        new(options.Mode.ToString(), started, DateTimeOffset.UtcNow, "failed", failurePoint, errors, bootstrap, adoption, modules);

    private static string Sanitize(Exception exception) => exception switch
    {
        SqlException sqlException => $"SQL Server operation failed (error {sqlException.Number}).",
        _ => exception.Message
    };

    private static bool IsAuthAdoptionBlocker(string error) =>
        error.StartsWith("Auth recognized legacy", StringComparison.Ordinal) ||
        error.StartsWith("Auth has a complete schema", StringComparison.Ordinal) ||
        error.StartsWith("Auth history contains foreign or unknown MigrationId", StringComparison.Ordinal) &&
        AuthLegacyMigrationManifest.AllLegacyIds.Any(id => error.Contains($"'{id}'", StringComparison.Ordinal));
}

namespace IFX.DatabaseMigrator;

public enum MigratorMode
{
    Preflight,
    DryRun,
    Apply,
    Validate,
    Scripts
}

public sealed record MigratorOptions(
    MigratorMode Mode,
    string ReportPath,
    bool ExplicitAuthAdoption,
    string ArtifactDirectory,
    string ReleaseManifestPath)
{
    public static MigratorOptions Parse(string[] args)
    {
        var mode = MigratorMode.Preflight;
        var report = "artifacts/database-migrator/report.json";
        var artifactDirectory = "artifacts/database-migrator/release";
        var releaseManifest = "deployment/release-manifest.json";
        var explicitAuthAdoption = false;
        for (var index = 0; index < args.Length; index++)
        {
            switch (args[index])
            {
                case "--mode" when index + 1 < args.Length:
                    var value = args[++index].Replace("-", string.Empty, StringComparison.Ordinal);
                    if (!Enum.TryParse<MigratorMode>(value, true, out mode))
                    {
                        throw new ArgumentException("Mode must be preflight, dry-run, apply, validate, or scripts.");
                    }
                    break;
                case "--preflight":
                    mode = MigratorMode.Preflight;
                    break;
                case "--dry-run":
                    mode = MigratorMode.DryRun;
                    break;
                case "--apply":
                    mode = MigratorMode.Apply;
                    break;
                case "--validate":
                    mode = MigratorMode.Validate;
                    break;
                case "--scripts":
                    mode = MigratorMode.Scripts;
                    break;
                case "--report" when index + 1 < args.Length:
                    report = args[++index];
                    break;
                case "--explicit-auth-adoption":
                    explicitAuthAdoption = true;
                    break;
                case "--artifact-dir" when index + 1 < args.Length:
                    artifactDirectory = args[++index];
                    break;
                case "--release-manifest" when index + 1 < args.Length:
                    releaseManifest = args[++index];
                    break;
                default:
                    throw new ArgumentException($"Unknown or incomplete argument '{args[index]}'.");
            }
        }

        return new MigratorOptions(
            mode,
            Path.GetFullPath(report),
            explicitAuthAdoption,
            Path.GetFullPath(artifactDirectory),
            Path.GetFullPath(releaseManifest));
    }
}

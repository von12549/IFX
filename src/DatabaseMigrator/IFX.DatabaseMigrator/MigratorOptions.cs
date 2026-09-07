namespace IFX.DatabaseMigrator;

public enum MigratorMode
{
    Preflight,
    DryRun,
    Apply,
    Validate
}

public sealed record MigratorOptions(
    MigratorMode Mode,
    string ReportPath,
    bool ExplicitAuthAdoption)
{
    public static MigratorOptions Parse(string[] args)
    {
        var mode = MigratorMode.Preflight;
        var report = "artifacts/database-migrator/report.json";
        var explicitAuthAdoption = false;
        for (var index = 0; index < args.Length; index++)
        {
            switch (args[index])
            {
                case "--mode" when index + 1 < args.Length:
                    var value = args[++index].Replace("-", string.Empty, StringComparison.Ordinal);
                    if (!Enum.TryParse<MigratorMode>(value, true, out mode))
                    {
                        throw new ArgumentException("Mode must be preflight, dry-run, apply, or validate.");
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
                case "--report" when index + 1 < args.Length:
                    report = args[++index];
                    break;
                case "--explicit-auth-adoption":
                    explicitAuthAdoption = true;
                    break;
                default:
                    throw new ArgumentException($"Unknown or incomplete argument '{args[index]}'.");
            }
        }

        return new MigratorOptions(mode, Path.GetFullPath(report), explicitAuthAdoption);
    }
}

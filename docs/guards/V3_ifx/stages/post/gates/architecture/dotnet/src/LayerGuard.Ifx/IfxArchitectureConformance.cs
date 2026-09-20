namespace LayerGuard.Ifx;

/// The IFX entry point to the Architecture Conformance Gate. IFX policy binding tests and the IFX host call this facade
/// instead of the engine, so the project path and the entry point stay the same across the separation (Plan 06 P6.3, D27).
public static class IfxArchitectureConformance
{
    private static readonly object Gate = new();
    private static bool registered;

    /// Registers the IFX policy binding once; the engine itself knows none of the IFX gate rules.
    public static void Register()
    {
        lock (Gate)
        {
            if (registered) return;
            PolicyBindings.Register(new IfxGatePolicyBinding());
            registered = true;
        }
    }

    public static Report Analyze(string path, string? configPath)
    {
        Register();
        return Analyzer.Analyze(path, configPath);
    }
}

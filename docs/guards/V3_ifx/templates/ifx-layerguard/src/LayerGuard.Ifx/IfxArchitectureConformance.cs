namespace LayerGuard.Ifx;

/// The IFX entry point to the Architecture Conformance Gate. IFX policy binding tests call this facade instead of the
/// engine, so the project path and the entry point stay the same when the IFX policy binding is separated from the
/// generic engine (Plan 06 P6.3, D27). Until then it forwards to the engine, which still holds the binding.
public static class IfxArchitectureConformance
{
    public static Report Analyze(string path, string? configPath) => Analyzer.Analyze(path, configPath);
}

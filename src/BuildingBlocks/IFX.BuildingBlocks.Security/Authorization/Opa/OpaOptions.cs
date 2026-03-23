namespace IFX.BuildingBlocks.Security.Authorization.Opa;

public class OpaOptions
{
    public const string SectionName = "Opa";

    public string BaseUrl { get; set; } = "http://localhost:8181";
    public int TimeoutSeconds { get; set; } = 5;

    /// <summary>
    /// When true, OPA unavailability is treated as a deny (fail closed).
    /// Default: true (secure by default).
    /// </summary>
    public bool FailClosed { get; set; } = true;

    /// <summary>
    /// When false, NullOpaPolicyClient is used (always allow). Useful for local dev without OPA.
    /// </summary>
    public bool Enabled { get; set; } = true;
}

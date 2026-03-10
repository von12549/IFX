namespace IFX.Platform.Shared.Configuration;

/// <summary>
/// Base interface for platform service settings.
/// </summary>
public interface IPlatformSettings
{
    /// <summary>
    /// Gets the configuration section name for this settings type.
    /// </summary>
    static abstract string SectionName { get; }

    /// <summary>
    /// Gets whether the service is enabled.
    /// </summary>
    bool Enabled { get; }
}

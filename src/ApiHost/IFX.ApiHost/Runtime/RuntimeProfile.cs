namespace IFX.ApiHost.Runtime;

public sealed record RuntimeProfile(RuntimeRole Role, RuntimeCapabilities Capabilities)
{
    public string RoleName => Role.ToString().ToLowerInvariant();
}

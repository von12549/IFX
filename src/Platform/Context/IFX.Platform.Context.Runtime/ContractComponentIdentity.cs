namespace IFX.Platform.Context.Runtime;

public sealed record ContractComponentIdentity
{
    public ContractComponentIdentity(string system, string component, int version)
    {
        System = RequireIdentity(system, nameof(system));
        Component = RequireIdentity(component, nameof(component));
        Version = version > 0
            ? version
            : throw new ArgumentOutOfRangeException(nameof(version));
    }

    public string System { get; }

    public string Component { get; }

    public int Version { get; }

    private static string RequireIdentity(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 128 || value.Any(character =>
                !char.IsAsciiLetterOrDigit(character) && character is not ('.' or '-')) || value.Any(char.IsUpper))
        {
            throw new ArgumentException(
                "Contract component identity must use lowercase letters, digits, dots or hyphens.",
                parameterName);
        }

        return value;
    }
}

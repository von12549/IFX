using System.Text.RegularExpressions;

namespace IFX.Platform.Messaging.Contracts;

public sealed partial record EventSchemaIdentity
{
    public EventSchemaIdentity(string name, int majorVersion)
    {
        ArgumentNullException.ThrowIfNull(name);
        var match = IdentityPattern().Match(name);
        if (!match.Success || !int.TryParse(match.Groups[1].Value, out var suffixVersion))
        {
            throw new ArgumentException("Event identity must be lowercase and end in .vN.", nameof(name));
        }

        if (majorVersion <= 0 || suffixVersion != majorVersion)
        {
            throw new ArgumentException("Event identity suffix and major version must match and be positive.", nameof(majorVersion));
        }

        Name = name;
        MajorVersion = majorVersion;
    }

    public string Name { get; }

    public int MajorVersion { get; }

    [GeneratedRegex(@"^ifx\.[a-z0-9-]+(?:\.[a-z0-9-]+)+\.v([1-9][0-9]*)$", RegexOptions.CultureInvariant)]
    private static partial Regex IdentityPattern();
}

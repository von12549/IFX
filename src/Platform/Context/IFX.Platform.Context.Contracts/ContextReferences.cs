using System.Text.RegularExpressions;

namespace IFX.Platform.Context.Contracts;

public enum ActorKind
{
    User = 1,
    Service = 2,
    System = 3
}

public enum ContextProvenance
{
    Trusted = 1,
    Synthesized = 2
}

public sealed record ActorReference
{
    public ActorReference(ActorKind kind, string id)
    {
        if (!Enum.IsDefined(kind))
        {
            throw new ArgumentOutOfRangeException(nameof(kind));
        }

        Kind = kind;
        Id = ProtocolTextConstants.RequireOpaque(id, nameof(id), 128);
    }

    public ActorKind Kind { get; }

    public string Id { get; }
}

public sealed record SourceReference
{
    public SourceReference(string system, string component, int version)
    {
        System = ProtocolTextConstants.RequireIdentity(system, nameof(system));
        Component = ProtocolTextConstants.RequireIdentity(component, nameof(component));
        Version = version > 0 ? version : throw new ArgumentOutOfRangeException(nameof(version));
    }

    public string System { get; }

    public string Component { get; }

    public int Version { get; }
}

internal static partial class ProtocolTextConstants
{
    [GeneratedRegex("^[a-z0-9][a-z0-9.-]{0,126}[a-z0-9]$|^[a-z0-9]$", RegexOptions.CultureInvariant)]
    private static partial Regex IdentityPattern();

    public static string RequireIdentity(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value) || !IdentityPattern().IsMatch(value))
        {
            throw new ArgumentException("Protocol identity must use lowercase letters, digits, dots or hyphens.", parameterName);
        }

        return value;
    }

    public static string RequireOpaque(string value, string parameterName, int maximumLength)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > maximumLength || value.Any(char.IsControl))
        {
            throw new ArgumentException("Opaque protocol value is missing or invalid.", parameterName);
        }

        return value;
    }
}

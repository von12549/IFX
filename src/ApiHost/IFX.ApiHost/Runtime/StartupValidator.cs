using App.Abstractions;
using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.AspNetCore.Routing;

namespace IFX.ApiHost.Runtime;

public static class StartupBoundaryVerifier
{
    private static readonly IReadOnlyDictionary<string, string> ModuleNames = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["auth"] = "Auth",
        ["crm"] = "CRM",
        ["registry"] = "Registry",
        ["holdings"] = "Holdings",
        ["transaction"] = "Transaction"
    };

    public static IReadOnlyList<IModuleInstaller> ValidateComposition(
        IEnumerable<IModuleInstaller> installers,
        ModuleManifest moduleManifest,
        ReleaseRuntimeManifest releaseManifest,
        RuntimeProfile profile)
    {
        if (moduleManifest.FormatVersion != 1 || releaseManifest.FormatVersion != 1 ||
            !string.Equals(moduleManifest.ReleaseVersion, releaseManifest.ReleaseId, StringComparison.Ordinal))
        {
            throw new StartupValidationException("G04-STARTUP-RELEASE-MISMATCH", "Module and release manifest versions do not match.");
        }

        var entries = moduleManifest.Modules.ToArray();
        if (entries.Length != ModuleNames.Count || entries.Any(x => !x.Required) || entries.Select(x => x.ModuleId).Distinct(StringComparer.OrdinalIgnoreCase).Count() != entries.Length)
        {
            throw new StartupValidationException("G04-STARTUP-MODULE-SET-INVALID", "The manifest must contain exactly one required entry for every business module.");
        }

        var required = releaseManifest.RequiredModuleIds.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToArray();
        var declared = entries.Select(x => x.ModuleId).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToArray();
        if (!required.SequenceEqual(declared, StringComparer.OrdinalIgnoreCase) || !releaseManifest.HostArtifact.AllowedRoles.Contains(profile.RoleName, StringComparer.OrdinalIgnoreCase))
        {
            throw new StartupValidationException("G04-STARTUP-RELEASE-MISMATCH", "Release role or required module identity does not match the module manifest.");
        }

        var byName = installers.GroupBy(x => x.ModuleName, StringComparer.OrdinalIgnoreCase).ToDictionary(x => x.Key, x => x.ToArray(), StringComparer.OrdinalIgnoreCase);
        var ordered = new List<IModuleInstaller>(entries.Length);
        foreach (var entry in entries)
        {
            if (!ModuleNames.TryGetValue(entry.ModuleId, out var expectedName) || !byName.TryGetValue(expectedName, out var matches) || matches.Length != 1)
            {
                throw new StartupValidationException("G04-STARTUP-MODULE-COMPOSITION-INVALID", $"Module '{entry.ModuleId}' must resolve to exactly one installer.");
            }

            ordered.Add(matches[0]);
        }

        if (byName.Count != entries.Length)
        {
            throw new StartupValidationException("G04-STARTUP-MODULE-COMPOSITION-INVALID", "An installer is not declared by the required module manifest.");
        }

        return ordered;
    }

    public static void ValidateEndpointIdentity(EndpointDataSource endpointDataSource)
    {
        var duplicates = endpointDataSource.Endpoints
            .OfType<RouteEndpoint>()
            .SelectMany(endpoint =>
            {
                var methods = endpoint.Metadata.GetMetadata<IHttpMethodMetadata>()?.HttpMethods ?? ["*"];
                return methods.Select(method => $"{method.ToUpperInvariant()} {endpoint.RoutePattern.RawText}");
            })
            .GroupBy(identity => identity, StringComparer.OrdinalIgnoreCase)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToArray();

        if (duplicates.Length > 0)
        {
            throw new StartupValidationException("G04-STARTUP-ENDPOINT-COLLISION", $"Duplicate endpoint identities: {string.Join(", ", duplicates)}");
        }
    }
}

public sealed class StartupValidationException : InvalidOperationException
{
    public StartupValidationException(string reasonCode, string message, Exception? innerException = null) : base(message, innerException) => ReasonCode = reasonCode;

    public string ReasonCode { get; }
}

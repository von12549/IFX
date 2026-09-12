using Hangfire.Common;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.BackgroundJobs.Composition;

/// <summary>Explicit compatibility for a persisted job type after an assembly rename.</summary>
public sealed record BackgroundJobTypeAlias(string LegacyTypeName, Type TargetType);

public sealed class BackgroundJobTypeResolver
{
    private readonly IReadOnlyDictionary<string, Type> _aliases;

    public BackgroundJobTypeResolver(IEnumerable<BackgroundJobTypeAlias> aliases)
    {
        _aliases = aliases.ToDictionary(alias => Key(alias.LegacyTypeName), alias => alias.TargetType, StringComparer.Ordinal);
    }

    public Type Resolve(string typeName) => _aliases.TryGetValue(Key(typeName), out var type)
        ? type
        : TypeHelper.DefaultTypeResolver(typeName);

    private static string Key(string typeName)
    {
        // Only simple, explicitly registered type/assembly pairs are aliases. Generic types
        // retain their full name and go through Hangfire's normal resolver.
        if (typeName.Contains('[')) return typeName;
        var parts = typeName.Split(',', 3, StringSplitOptions.TrimEntries);
        return parts.Length >= 2 ? $"{parts[0]}, {parts[1]}" : typeName;
    }
}

public static class BackgroundJobTypeAliasRegistration
{
    public static IServiceCollection AddBackgroundJobTypeAlias<T>(this IServiceCollection services, string legacyTypeName)
    {
        services.AddSingleton(new BackgroundJobTypeAlias(legacyTypeName, typeof(T)));
        return services;
    }
}

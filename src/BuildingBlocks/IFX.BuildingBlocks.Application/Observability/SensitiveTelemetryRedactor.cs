using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace IFX.BuildingBlocks.Application.Observability;

public enum TelemetryValueHandling
{
    Allow = 1,
    Pseudonymize = 2,
    Redact = 3,
    Drop = 4
}

public enum TelemetrySignal
{
    OperationalLog = 1,
    TraceTag = 2,
    MetricLabel = 3,
    Baggage = 4
}

public sealed record TelemetryRedaction(TelemetryValueHandling Handling, string? Value);

public sealed partial class SensitiveTelemetryRedactor
{
    public const string RedactedValue = "[REDACTED]";
    public const string DroppedValue = "[DROPPED]";
    private readonly byte[] _key;

    public SensitiveTelemetryRedactor(string keyId, ReadOnlySpan<byte> key)
    {
        if (!KeyIdPattern().IsMatch(keyId))
        {
            throw new ArgumentException("Telemetry pseudonym key ID must be a bounded lowercase identity.", nameof(keyId));
        }

        if (key.Length < 32)
        {
            throw new ArgumentException("Telemetry pseudonym keys require at least 256 bits.", nameof(key));
        }

        KeyId = keyId;
        _key = key.ToArray();
    }

    public string KeyId { get; }

    public TelemetryRedaction Redact(
        string fieldName,
        object? value,
        TelemetrySignal signal = TelemetrySignal.OperationalLog)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fieldName);

        if (C4NamePattern().IsMatch(fieldName))
        {
            return new TelemetryRedaction(TelemetryValueHandling.Drop, DroppedValue);
        }

        if (C3NamePattern().IsMatch(fieldName))
        {
            return SensitiveSignal(signal)
                ? new TelemetryRedaction(TelemetryValueHandling.Drop, DroppedValue)
                : new TelemetryRedaction(TelemetryValueHandling.Redact, RedactedValue);
        }

        if (C2NamePattern().IsMatch(fieldName))
        {
            var text = value?.ToString() ?? string.Empty;
            return SensitiveSignal(signal)
                ? new TelemetryRedaction(TelemetryValueHandling.Drop, DroppedValue)
                : new TelemetryRedaction(TelemetryValueHandling.Pseudonymize, Pseudonymize(text));
        }

        if (AllowedFields.Contains(fieldName))
        {
            var text = value?.ToString() ?? string.Empty;
            return new TelemetryRedaction(TelemetryValueHandling.Allow, text.Length <= 256 ? text : text[..256]);
        }

        return SensitiveSignal(signal)
            ? new TelemetryRedaction(TelemetryValueHandling.Drop, DroppedValue)
            : new TelemetryRedaction(TelemetryValueHandling.Redact, RedactedValue);
    }

    private static bool SensitiveSignal(TelemetrySignal signal) =>
        signal is TelemetrySignal.MetricLabel or TelemetrySignal.Baggage;

    public string Pseudonymize(string value)
    {
        var digest = HMACSHA256.HashData(_key, Encoding.UTF8.GetBytes(value));
        return $"hmac:{KeyId}:{Convert.ToHexString(digest.AsSpan(0, 12)).ToLowerInvariant()}";
    }

    public static SensitiveTelemetryRedactor CreateEphemeral(string keyId = "ephemeral-v1") =>
        new(keyId, RandomNumberGenerator.GetBytes(32));

    private static readonly HashSet<string> AllowedFields = new(StringComparer.OrdinalIgnoreCase)
    {
        "Action", "Application", "ConditionCount", "Count", "Decision", "Delay", "Duration",
        "ElapsedMilliseconds", "EnqueueAt", "Environment", "EventType", "FailureType", "Level",
        "Method", "Module", "Permission", "Provenance", "Queue", "ReasonCode", "RequestName",
        "ResourceType", "Role", "RouteName", "SchemaVersion", "Scope", "SourceContext", "Status",
        "StatusCode", "TemplateId", "ThreadId", "Version"
    };

    [GeneratedRegex("(password|token|authorization|cookie|otp|secret|privatekey|connectionstring)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex C4NamePattern();

    [GeneratedRegex("(email|username|issuer|subject|ipaddress|failureReason|rejectionReason|body|payload|requestBody|responseBody|displayName)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex C3NamePattern();

    [GeneratedRegex("(id|reference|account|correlation|operation|causation|resource)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex C2NamePattern();

    [GeneratedRegex("^[a-z0-9][a-z0-9.-]{0,63}$", RegexOptions.CultureInvariant)]
    private static partial Regex KeyIdPattern();
}

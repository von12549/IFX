using IFX.BuildingBlocks.Application.Observability;

namespace IFX.ApiHost.Observability;

public static class SensitiveTelemetryRedactorFactory
{
    public const string KeyIdConfiguration = "Observability:PseudonymKeyId";
    public const string KeyConfiguration = "Observability:PseudonymKeyBase64";

    public static SensitiveTelemetryRedactor Create(
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        var keyId = configuration[KeyIdConfiguration];
        var encodedKey = configuration[KeyConfiguration];
        if (string.IsNullOrWhiteSpace(keyId) || string.IsNullOrWhiteSpace(encodedKey))
        {
            if (environment.IsProduction())
            {
                throw new InvalidOperationException(
                    "Production observability pseudonym key configuration is required.");
            }

            return SensitiveTelemetryRedactor.CreateEphemeral();
        }

        try
        {
            return new SensitiveTelemetryRedactor(keyId, Convert.FromBase64String(encodedKey));
        }
        catch (FormatException exception)
        {
            throw new InvalidOperationException(
                "Observability pseudonym key configuration is invalid.",
                exception);
        }
    }
}

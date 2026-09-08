using IFX.ApiHost.Observability;
using IFX.BuildingBlocks.Application.Observability;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

namespace IFX.IntegrationTests.Observability;

public sealed class SensitiveObservabilityTests
{
    private static readonly byte[] KeyA = Enumerable.Range(1, 32).Select(value => (byte)value).ToArray();
    private static readonly byte[] KeyB = Enumerable.Range(33, 32).Select(value => (byte)value).ToArray();

    [Fact]
    public void Captured_sink_removes_sensitive_values_payloads_and_exception_details()
    {
        const string email = "g05-sentinel@example.invalid";
        const string token = "g05-secret-access-token";
        const string payload = "g05-full-contract-payload";
        const string exceptionDetail = "g05-secret-database-detail";
        var userId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var tenantId = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var capture = new CapturingSink();

        using var destination = new LoggerConfiguration().WriteTo.Sink(capture).CreateLogger();
        using var safeSink = new SensitiveLogEventSink(
            destination,
            new SensitiveTelemetryRedactor("rotation-a", KeyA));
        using var logger = new LoggerConfiguration().WriteTo.Sink(safeSink).CreateLogger();

        logger.Error(
            new InvalidOperationException(exceptionDetail),
            "Delivery failed for {UserId} in {TenantId} with {Email}, {AccessToken}, {@Payload} and {ReasonCode}",
            userId,
            tenantId,
            email,
            token,
            payload,
            "provider_unavailable");

        var captured = Assert.Single(capture.Events);
        var rendered = captured.RenderMessage();
        rendered.Should().NotContain(email)
            .And.NotContain(token)
            .And.NotContain(payload)
            .And.NotContain(exceptionDetail)
            .And.NotContain(userId.ToString())
            .And.NotContain(tenantId.ToString());
        rendered.Should().Contain("hmac:rotation-a:")
            .And.Contain(SensitiveTelemetryRedactor.RedactedValue)
            .And.Contain("provider_unavailable");
        captured.Exception.Should().BeNull();
        captured.Properties.Should().ContainKey("FailureType")
            .WhoseValue.ToString().Should().Contain(nameof(InvalidOperationException));
        captured.Properties.Should().NotContainKey("AccessToken");
    }

    [Fact]
    public void Pseudonym_key_rotation_changes_output_without_exposing_source_value()
    {
        const string source = "g05-stable-user-reference";
        var first = new SensitiveTelemetryRedactor("rotation-a", KeyA).Redact("UserId", source);
        var second = new SensitiveTelemetryRedactor("rotation-b", KeyB).Redact("UserId", source);

        first.Handling.Should().Be(TelemetryValueHandling.Pseudonymize);
        second.Handling.Should().Be(TelemetryValueHandling.Pseudonymize);
        first.Value.Should().StartWith("hmac:rotation-a:").And.NotContain(source);
        second.Value.Should().StartWith("hmac:rotation-b:").And.NotContain(source);
        first.Value.Should().NotBe(second.Value);
    }

    [Fact]
    public void Production_requires_external_pseudonym_key_configuration()
    {
        var configuration = new ConfigurationBuilder().Build();

        var act = () => SensitiveTelemetryRedactorFactory.Create(
            configuration,
            new StubEnvironment("Production"));

        act.Should().Throw<InvalidOperationException>()
            .WithMessage("Production observability pseudonym key configuration is required.");
    }

    [Fact]
    public void External_key_configuration_supports_explicit_rotation_identity()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [SensitiveTelemetryRedactorFactory.KeyIdConfiguration] = "rotation-b",
                [SensitiveTelemetryRedactorFactory.KeyConfiguration] = Convert.ToBase64String(KeyB)
            })
            .Build();

        var redactor = SensitiveTelemetryRedactorFactory.Create(
            configuration,
            new StubEnvironment("Production"));

        redactor.KeyId.Should().Be("rotation-b");
    }

    [Theory]
    [InlineData(TelemetrySignal.TraceTag, "TenantId", "tenant-g05-sentinel", TelemetryValueHandling.Pseudonymize)]
    [InlineData(TelemetrySignal.TraceTag, "Email", "trace-g05@example.invalid", TelemetryValueHandling.Redact)]
    [InlineData(TelemetrySignal.MetricLabel, "TenantId", "metric-tenant-g05", TelemetryValueHandling.Drop)]
    [InlineData(TelemetrySignal.MetricLabel, "AccessToken", "metric-g05-secret", TelemetryValueHandling.Drop)]
    [InlineData(TelemetrySignal.MetricLabel, "ReasonCode", "provider_unavailable", TelemetryValueHandling.Allow)]
    [InlineData(TelemetrySignal.Baggage, "CorrelationId", "baggage-g05", TelemetryValueHandling.Drop)]
    public void Trace_and_metric_values_share_the_central_classifier(
        TelemetrySignal signal,
        string field,
        string sentinel,
        TelemetryValueHandling expected)
    {
        var result = new SensitiveTelemetryRedactor("rotation-a", KeyA).Redact(field, sentinel, signal);

        result.Handling.Should().Be(expected);
        if (expected == TelemetryValueHandling.Allow)
        {
            result.Value.Should().Be(sentinel);
        }
        else
        {
            result.Value.Should().NotContain(sentinel);
        }
    }

    private sealed class CapturingSink : ILogEventSink
    {
        public List<LogEvent> Events { get; } = [];

        public void Emit(LogEvent logEvent) => Events.Add(logEvent);
    }

    private sealed class StubEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;
        public string ApplicationName { get; set; } = "IFX.IntegrationTests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}

using IFX.Platform.Messaging.Composition.Dispatching;

namespace IFX.IntegrationTests.Runtime;

public sealed class MessageBackpressurePolicyTests
{
    private static readonly BacklogThreshold Threshold = new(
        TimeSpan.FromMinutes(2), TimeSpan.FromMinutes(10), 500, 5000, 1, 10, 0.85, TimeSpan.FromSeconds(30));

    [Fact]
    public void Evaluate_DoesNotUseMessageCountAlone()
    {
        var observation = Observation(count: 10000, age: TimeSpan.FromSeconds(10), rate: 100);

        MessageBackpressurePolicy.Evaluate(observation, Threshold, DateTimeOffset.UtcNow).Severity
            .Should().Be(BacklogSeverity.Healthy);
    }

    [Fact]
    public void Evaluate_TransportStallWithOldBacklog_IsCritical()
    {
        var observation = Observation(count: 5000, age: TimeSpan.FromMinutes(10), rate: 0);

        var result = MessageBackpressurePolicy.Evaluate(observation, Threshold, DateTimeOffset.UtcNow);

        result.Severity.Should().Be(BacklogSeverity.Critical);
        result.ReasonCode.Should().Be("G04-BACKLOG-CRITICAL");
    }

    [Fact]
    public void Evaluate_DeadLetterGrowth_IsWarningThenCritical()
    {
        MessageBackpressurePolicy.Evaluate(Observation(deadLetters: 1), Threshold, DateTimeOffset.UtcNow).Severity
            .Should().Be(BacklogSeverity.Warning);
        MessageBackpressurePolicy.Evaluate(Observation(deadLetters: 10), Threshold, DateTimeOffset.UtcNow).Severity
            .Should().Be(BacklogSeverity.Critical);
    }

    [Fact]
    public void Decide_BlocksOnlyRelatedBacklogProducingCommand()
    {
        var critical = MessageBackpressurePolicy.Evaluate(
            Observation(module: "crm", category: "party", count: 5000, age: TimeSpan.FromMinutes(10), rate: 0),
            Threshold,
            DateTimeOffset.UtcNow);

        MessageBackpressurePolicy.Decide(new("crm", "party", true), new[] { critical }).Allowed.Should().BeFalse();
        MessageBackpressurePolicy.Decide(new("crm", "party", false), new[] { critical }).Allowed.Should().BeTrue();
        MessageBackpressurePolicy.Decide(new("registry", "product", true), new[] { critical }).Allowed.Should().BeTrue();
    }

    [Fact]
    public void Decide_RecoveryReopensProduction()
    {
        var healthy = MessageBackpressurePolicy.Evaluate(Observation(), Threshold, DateTimeOffset.UtcNow);

        var decision = MessageBackpressurePolicy.Decide(new("crm", "party", true), new[] { healthy });

        decision.Allowed.Should().BeTrue();
        decision.RetryAfter.Should().BeNull();
    }

    private static MessageBacklogObservation Observation(
        string module = "crm",
        string category = "party",
        long count = 0,
        TimeSpan? age = null,
        double rate = 10,
        long deadLetters = 0) => new(
            module,
            category,
            count,
            age ?? TimeSpan.Zero,
            RetryCount: 0,
            DeadLetterCount: deadLetters,
            LastSucceeded: DateTimeOffset.UtcNow,
            ProcessingRatePerSecond: rate,
            StorageUtilization: 0.1,
            ExpiredLeaseCount: 0,
            DuplicateRate: 0);
}

namespace IFX.Platform.Messaging.Runtime;

public enum BacklogSeverity { Healthy, Warning, Critical }

public sealed record MessageBacklogObservation(
    string ModuleId, string EventCategory, long PendingCount, TimeSpan OldestPendingAge,
    long RetryCount, long DeadLetterCount, DateTimeOffset? LastSucceeded,
    double ProcessingRatePerSecond, double StorageUtilization, long ExpiredLeaseCount, double DuplicateRate,
    long ConsecutiveFailures = 0);

public sealed record BacklogThreshold(
    TimeSpan WarningAge, TimeSpan CriticalAge, long WarningCount, long CriticalCount,
    long WarningDeadLetters, long CriticalDeadLetters, double CriticalStorageUtilization, TimeSpan RetryAfter,
    long WarningConsecutiveFailures, long CriticalConsecutiveFailures,
    TimeSpan WarningSilence, TimeSpan CriticalSilence);

public sealed record BacklogEvaluation(
    string ModuleId, string EventCategory, BacklogSeverity Severity, string ReasonCode,
    DateTimeOffset EvaluatedAt, TimeSpan RetryAfter);

public sealed record MessageProductionIntent(string ModuleId, string EventCategory, bool ExpandsBacklog);
public sealed record BackpressureDecision(bool Allowed, bool Retryable, string ReasonCode, TimeSpan? RetryAfter);

public static class MessageBackpressurePolicy
{
    public static BacklogEvaluation Evaluate(MessageBacklogObservation observation, BacklogThreshold threshold, DateTimeOffset now)
    {
        Validate(observation, threshold);
        var stalled = observation.ProcessingRatePerSecond <= 0;
        var dispatcherSilence = observation.PendingCount == 0
            ? TimeSpan.Zero
            : observation.LastSucceeded is { } lastSucceeded
                ? now - lastSucceeded
                : observation.OldestPendingAge;
        var criticalFailures = observation.ConsecutiveFailures >= threshold.CriticalConsecutiveFailures;
        var warningFailures = observation.ConsecutiveFailures >= threshold.WarningConsecutiveFailures;
        var criticalSilence = stalled && dispatcherSilence >= threshold.CriticalSilence;
        var warningSilence = stalled && dispatcherSilence >= threshold.WarningSilence;
        var criticalBacklog = observation.DeadLetterCount >= threshold.CriticalDeadLetters ||
            observation.StorageUtilization >= threshold.CriticalStorageUtilization ||
            (observation.OldestPendingAge >= threshold.CriticalAge && observation.PendingCount >= threshold.CriticalCount && stalled);
        var warningBacklog = observation.DeadLetterCount >= threshold.WarningDeadLetters ||
            (observation.OldestPendingAge >= threshold.WarningAge && observation.PendingCount >= threshold.WarningCount);
        var critical = criticalFailures || criticalSilence || criticalBacklog;
        var warning = warningFailures || warningSilence || warningBacklog;
        var severity = critical ? BacklogSeverity.Critical : warning ? BacklogSeverity.Warning : BacklogSeverity.Healthy;
        return new BacklogEvaluation(observation.ModuleId, observation.EventCategory, severity,
            criticalFailures ? "G04-DELIVERY-FAILURES-CRITICAL" :
            criticalBacklog ? "G04-BACKLOG-CRITICAL" :
            criticalSilence ? "G04-DISPATCHER-SILENT-CRITICAL" :
            warningFailures ? "G04-DELIVERY-FAILURES-WARNING" :
            warningBacklog ? "G04-BACKLOG-WARNING" :
            warningSilence ? "G04-DISPATCHER-SILENT-WARNING" :
            "G04-BACKLOG-HEALTHY",
            now, threshold.RetryAfter);
    }

    public static BackpressureDecision Decide(MessageProductionIntent intent, IEnumerable<BacklogEvaluation> evaluations)
    {
        if (!intent.ExpandsBacklog) return new BackpressureDecision(true, false, "G04-BACKPRESSURE-NOT-APPLICABLE", null);
        var critical = evaluations.FirstOrDefault(item => item.Severity == BacklogSeverity.Critical &&
            string.Equals(item.ModuleId, intent.ModuleId, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(item.EventCategory, intent.EventCategory, StringComparison.OrdinalIgnoreCase));
        return critical is null
            ? new BackpressureDecision(true, false, "G04-BACKPRESSURE-OPEN", null)
            : new BackpressureDecision(false, true, "G04-BACKPRESSURE-RETRY", critical.RetryAfter);
    }

    private static void Validate(MessageBacklogObservation observation, BacklogThreshold threshold)
    {
        if (string.IsNullOrWhiteSpace(observation.ModuleId) || string.IsNullOrWhiteSpace(observation.EventCategory)) throw new ArgumentException("Module and event category are required.");
        if (threshold.WarningAge <= TimeSpan.Zero || threshold.WarningAge >= threshold.CriticalAge ||
            threshold.WarningCount < 0 || threshold.WarningCount >= threshold.CriticalCount ||
            threshold.WarningDeadLetters < 0 || threshold.WarningDeadLetters >= threshold.CriticalDeadLetters ||
            threshold.WarningConsecutiveFailures <= 0 || threshold.WarningConsecutiveFailures >= threshold.CriticalConsecutiveFailures ||
            threshold.WarningSilence <= TimeSpan.Zero || threshold.WarningSilence >= threshold.CriticalSilence ||
            threshold.CriticalStorageUtilization is <= 0 or > 1 || threshold.RetryAfter <= TimeSpan.Zero)
            throw new InvalidOperationException("G04-BACKPRESSURE-THRESHOLD-INVALID");
    }
}

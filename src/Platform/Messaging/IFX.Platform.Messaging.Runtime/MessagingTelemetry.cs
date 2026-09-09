using System.Collections.Concurrent;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace IFX.Platform.Messaging.Runtime;

public sealed record MessagingTelemetrySnapshot(
    string ModuleId,
    long DeliveryAttempts,
    long DeliverySuccesses,
    long DeliveryFailures,
    long DeadLettered,
    long ConsecutiveFailures,
    double SecondsSinceLastSuccess,
    double ProcessingRatePerSecond,
    OutboxBacklogSnapshot? Backlog);

public sealed class MessagingTelemetry : IDisposable
{
    public const string MeterName = "IFX.Platform.Messaging";
    private const string EventCategory = "integration";

    private readonly Meter _meter = new(MeterName, "1.0.0");
    private readonly Counter<long> _attempts;
    private readonly Counter<long> _successes;
    private readonly Counter<long> _failures;
    private readonly Counter<long> _deadLetters;
    private readonly ConcurrentDictionary<string, ModuleState> _states = new(StringComparer.OrdinalIgnoreCase);

    public MessagingTelemetry()
    {
        _attempts = _meter.CreateCounter<long>("ifx.messaging.delivery.attempts", unit: "{attempt}");
        _successes = _meter.CreateCounter<long>("ifx.messaging.delivery.successes", unit: "{message}");
        _failures = _meter.CreateCounter<long>("ifx.messaging.delivery.failures", unit: "{message}");
        _deadLetters = _meter.CreateCounter<long>("ifx.messaging.delivery.dead_letters", unit: "{message}");
        _meter.CreateObservableGauge("ifx.messaging.backlog.pending", ObservePending, unit: "{message}");
        _meter.CreateObservableGauge("ifx.messaging.backlog.oldest_age", ObserveOldestAge, unit: "s");
        _meter.CreateObservableGauge("ifx.messaging.backlog.retries", ObserveRetries, unit: "{message}");
        _meter.CreateObservableGauge("ifx.messaging.backlog.dead_letters", ObserveDeadLetters, unit: "{message}");
        _meter.CreateObservableGauge("ifx.messaging.backlog.leased", ObserveLeased, unit: "{message}");
        _meter.CreateObservableGauge("ifx.messaging.backlog.expired_leases", ObserveExpiredLeases, unit: "{message}");
        _meter.CreateObservableGauge("ifx.messaging.delivery.consecutive_failures", ObserveConsecutiveFailures, unit: "{failure}");
        _meter.CreateObservableGauge("ifx.messaging.delivery.seconds_since_success", ObserveSecondsSinceSuccess, unit: "s");
        _meter.CreateObservableGauge("ifx.messaging.delivery.rate", ObserveRates, unit: "{message}/s");
    }

    public void RecordAttempt(string moduleId)
    {
        State(moduleId).RecordAttempt();
        _attempts.Add(1, Tags(moduleId));
    }

    public void RecordSuccess(string moduleId, DateTimeOffset now)
    {
        State(moduleId).RecordSuccess(now);
        _successes.Add(1, Tags(moduleId));
    }

    public void RecordFailure(string moduleId, bool deadLetter)
    {
        State(moduleId).RecordFailure(deadLetter);
        _failures.Add(1, Tags(moduleId));
        if (deadLetter) _deadLetters.Add(1, Tags(moduleId));
    }

    public void RecordBacklog(OutboxBacklogSnapshot snapshot) => State(snapshot.ModuleId).RecordBacklog(snapshot);

    public MessagingTelemetrySnapshot Snapshot(string moduleId) => State(moduleId).Snapshot(moduleId, DateTimeOffset.UtcNow);

    public void Dispose() => _meter.Dispose();

    private ModuleState State(string moduleId)
    {
        if (string.IsNullOrWhiteSpace(moduleId)) throw new ArgumentException("Module id is required.", nameof(moduleId));
        return _states.GetOrAdd(moduleId, static _ => new ModuleState());
    }

    private static TagList Tags(string moduleId) => new() { { "module.id", moduleId }, { "event.category", EventCategory } };

    private IEnumerable<Measurement<long>> ObservePending() => ObserveLong(static snapshot => snapshot.Backlog?.PendingCount ?? 0);
    private IEnumerable<Measurement<long>> ObserveRetries() => ObserveLong(static snapshot => snapshot.Backlog?.RetryCount ?? 0);
    private IEnumerable<Measurement<long>> ObserveDeadLetters() => ObserveLong(static snapshot => snapshot.Backlog?.DeadLetterCount ?? 0);
    private IEnumerable<Measurement<long>> ObserveLeased() => ObserveLong(static snapshot => snapshot.Backlog?.LeasedCount ?? 0);
    private IEnumerable<Measurement<long>> ObserveExpiredLeases() => ObserveLong(static snapshot => snapshot.Backlog?.ExpiredLeaseCount ?? 0);
    private IEnumerable<Measurement<long>> ObserveConsecutiveFailures() => ObserveLong(static snapshot => snapshot.ConsecutiveFailures);

    private IEnumerable<Measurement<double>> ObserveOldestAge() => ObserveDouble(static snapshot => snapshot.Backlog?.OldestPendingAge.TotalSeconds ?? 0);
    private IEnumerable<Measurement<double>> ObserveSecondsSinceSuccess() => ObserveDouble(static snapshot => snapshot.SecondsSinceLastSuccess);
    private IEnumerable<Measurement<double>> ObserveRates() => ObserveDouble(static snapshot => snapshot.ProcessingRatePerSecond);

    private IEnumerable<Measurement<long>> ObserveLong(Func<MessagingTelemetrySnapshot, long> value) =>
        _states.Select(pair => new Measurement<long>(value(pair.Value.Snapshot(pair.Key, DateTimeOffset.UtcNow)), Tags(pair.Key)));

    private IEnumerable<Measurement<double>> ObserveDouble(Func<MessagingTelemetrySnapshot, double> value) =>
        _states.Select(pair => new Measurement<double>(value(pair.Value.Snapshot(pair.Key, DateTimeOffset.UtcNow)), Tags(pair.Key)));

    private sealed class ModuleState
    {
        private readonly object _sync = new();
        private long _attempts;
        private long _successes;
        private long _failures;
        private long _deadLettered;
        private long _consecutiveFailures;
        private DateTimeOffset? _firstAttemptAt;
        private DateTimeOffset? _lastSucceededAt;
        private long _rateBaselineSuccesses;
        private DateTimeOffset _rateBaselineAt = DateTimeOffset.UtcNow;
        private double _rate;
        private OutboxBacklogSnapshot? _backlog;

        public void RecordAttempt()
        {
            lock (_sync)
            {
                _attempts++;
                _firstAttemptAt ??= DateTimeOffset.UtcNow;
            }
        }

        public void RecordSuccess(DateTimeOffset now)
        {
            lock (_sync)
            {
                _successes++;
                _consecutiveFailures = 0;
                _lastSucceededAt = now;
                RefreshRate(now);
            }
        }

        public void RecordFailure(bool deadLetter)
        {
            lock (_sync)
            {
                _failures++;
                _consecutiveFailures++;
                if (deadLetter) _deadLettered++;
            }
        }

        public void RecordBacklog(OutboxBacklogSnapshot backlog) { lock (_sync) _backlog = backlog; }

        public MessagingTelemetrySnapshot Snapshot(string moduleId, DateTimeOffset now)
        {
            lock (_sync)
            {
                RefreshRate(now);
                var activityStartedAt = _lastSucceededAt ?? _firstAttemptAt;
                var secondsSinceSuccess = activityStartedAt is null ? 0 : Math.Max(0, (now - activityStartedAt.Value).TotalSeconds);
                return new(moduleId, _attempts, _successes, _failures, _deadLettered,
                    _consecutiveFailures, secondsSinceSuccess, _rate, _backlog);
            }
        }

        private void RefreshRate(DateTimeOffset now)
        {
            var elapsed = now - _rateBaselineAt;
            if (elapsed < TimeSpan.FromSeconds(1)) return;
            _rate = (_successes - _rateBaselineSuccesses) / elapsed.TotalSeconds;
            _rateBaselineSuccesses = _successes;
            _rateBaselineAt = now;
        }
    }
}

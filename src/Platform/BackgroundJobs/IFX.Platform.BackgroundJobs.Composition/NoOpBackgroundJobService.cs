using System.Linq.Expressions;
using IFX.Platform.BackgroundJobs.Contracts;
using Microsoft.Extensions.Logging;

namespace IFX.Platform.BackgroundJobs.Composition;

/// <summary>
/// No-op implementation of <see cref="IBackgroundJobService"/> for testing or environments without Hangfire.
/// Logs job operations but does not actually enqueue or schedule jobs.
/// </summary>
public class NoOpBackgroundJobService : IBackgroundJobService
{
    private readonly ILogger<NoOpBackgroundJobService> _logger;
    private int _jobCounter;

    public NoOpBackgroundJobService(ILogger<NoOpBackgroundJobService> logger)
    {
        _logger = logger;
    }

    public string Enqueue<T>(Expression<Action<T>> methodCall)
    {
        var jobId = $"noop-job-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would enqueue job {JobId}: {Method}", jobId, methodCall.Body);
        return jobId;
    }

    public string Enqueue<T>(Expression<Action<T>> methodCall, string queue)
    {
        var jobId = $"noop-job-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would enqueue job {JobId} on queue '{Queue}': {Method}", jobId, queue, methodCall.Body);
        return jobId;
    }

    public string Enqueue<T>(Expression<Func<T, Task>> methodCall)
    {
        var jobId = $"noop-job-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would enqueue async job {JobId}: {Method}", jobId, methodCall.Body);
        return jobId;
    }

    public string Enqueue<T>(Expression<Func<T, Task>> methodCall, string queue)
    {
        var jobId = $"noop-job-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would enqueue async job {JobId} on queue '{Queue}': {Method}", jobId, queue, methodCall.Body);
        return jobId;
    }

    public string Schedule<T>(Expression<Action<T>> methodCall, TimeSpan delay)
    {
        var jobId = $"noop-scheduled-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would schedule job {JobId} with delay {Delay}: {Method}", jobId, delay, methodCall.Body);
        return jobId;
    }

    public string Schedule<T>(Expression<Func<T, Task>> methodCall, TimeSpan delay)
    {
        var jobId = $"noop-scheduled-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would schedule async job {JobId} with delay {Delay}: {Method}", jobId, delay, methodCall.Body);
        return jobId;
    }

    public string Schedule<T>(Expression<Action<T>> methodCall, DateTimeOffset enqueueAt)
    {
        var jobId = $"noop-scheduled-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would schedule job {JobId} at {EnqueueAt}: {Method}", jobId, enqueueAt, methodCall.Body);
        return jobId;
    }

    public string Schedule<T>(Expression<Func<T, Task>> methodCall, DateTimeOffset enqueueAt)
    {
        var jobId = $"noop-scheduled-{Interlocked.Increment(ref _jobCounter)}";
        _logger.LogInformation("[NoOp] Would schedule async job {JobId} at {EnqueueAt}: {Method}", jobId, enqueueAt, methodCall.Body);
        return jobId;
    }

    public void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Action<T>> methodCall, string cronExpression)
    {
        _logger.LogInformation("[NoOp] Would add/update recurring job {JobId} with cron '{Cron}': {Method}",
            recurringJobId, cronExpression, methodCall.Body);
    }

    public void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Func<T, Task>> methodCall, string cronExpression)
    {
        _logger.LogInformation("[NoOp] Would add/update recurring async job {JobId} with cron '{Cron}': {Method}",
            recurringJobId, cronExpression, methodCall.Body);
    }

    public void RemoveRecurring(string recurringJobId)
    {
        _logger.LogInformation("[NoOp] Would remove recurring job {JobId}", recurringJobId);
    }

    public void TriggerRecurring(string recurringJobId)
    {
        _logger.LogInformation("[NoOp] Would trigger recurring job {JobId}", recurringJobId);
    }

    public bool Delete(string jobId)
    {
        _logger.LogInformation("[NoOp] Would delete job {JobId}", jobId);
        return true;
    }
}

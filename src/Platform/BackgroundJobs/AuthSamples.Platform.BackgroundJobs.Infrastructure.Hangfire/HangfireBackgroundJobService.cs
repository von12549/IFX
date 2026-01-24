using System.Linq.Expressions;
using AuthSamples.Platform.BackgroundJobs.Abstractions;
using Hangfire;
using Hangfire.Common;
using Hangfire.States;

namespace AuthSamples.Platform.BackgroundJobs.Infrastructure.Hangfire;

/// <summary>
/// Hangfire implementation of <see cref="IBackgroundJobService"/>.
/// </summary>
public class HangfireBackgroundJobService : IBackgroundJobService
{
    private readonly IBackgroundJobClient _backgroundJobClient;
    private readonly IRecurringJobManager _recurringJobManager;

    public HangfireBackgroundJobService(
        IBackgroundJobClient backgroundJobClient,
        IRecurringJobManager recurringJobManager)
    {
        _backgroundJobClient = backgroundJobClient;
        _recurringJobManager = recurringJobManager;
    }

    public string Enqueue<T>(Expression<Action<T>> methodCall)
    {
        return _backgroundJobClient.Enqueue(methodCall);
    }

    public string Enqueue<T>(Expression<Action<T>> methodCall, string queue)
    {
        var job = Job.FromExpression(methodCall);
        return _backgroundJobClient.Create(job, new EnqueuedState(queue));
    }

    public string Enqueue<T>(Expression<Func<T, Task>> methodCall)
    {
        return _backgroundJobClient.Enqueue(methodCall);
    }

    public string Enqueue<T>(Expression<Func<T, Task>> methodCall, string queue)
    {
        var job = Job.FromExpression(methodCall);
        return _backgroundJobClient.Create(job, new EnqueuedState(queue));
    }

    public string Schedule<T>(Expression<Action<T>> methodCall, TimeSpan delay)
    {
        return _backgroundJobClient.Schedule(methodCall, delay);
    }

    public string Schedule<T>(Expression<Func<T, Task>> methodCall, TimeSpan delay)
    {
        return _backgroundJobClient.Schedule(methodCall, delay);
    }

    public string Schedule<T>(Expression<Action<T>> methodCall, DateTimeOffset enqueueAt)
    {
        return _backgroundJobClient.Schedule(methodCall, enqueueAt);
    }

    public string Schedule<T>(Expression<Func<T, Task>> methodCall, DateTimeOffset enqueueAt)
    {
        return _backgroundJobClient.Schedule(methodCall, enqueueAt);
    }

    public void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Action<T>> methodCall, string cronExpression)
    {
        _recurringJobManager.AddOrUpdate(recurringJobId, methodCall, cronExpression);
    }

    public void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Func<T, Task>> methodCall, string cronExpression)
    {
        _recurringJobManager.AddOrUpdate(recurringJobId, methodCall, cronExpression);
    }

    public void RemoveRecurring(string recurringJobId)
    {
        _recurringJobManager.RemoveIfExists(recurringJobId);
    }

    public void TriggerRecurring(string recurringJobId)
    {
        _recurringJobManager.Trigger(recurringJobId);
    }

    public bool Delete(string jobId)
    {
        return _backgroundJobClient.Delete(jobId);
    }
}

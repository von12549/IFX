using System.Linq.Expressions;

namespace IFX.Platform.BackgroundJobs.Contracts;

public interface IBackgroundJobService
{
    string Enqueue<T>(Expression<Action<T>> methodCall);
    string Enqueue<T>(Expression<Action<T>> methodCall, string queue);
    string Enqueue<T>(Expression<Func<T, Task>> methodCall);
    string Enqueue<T>(Expression<Func<T, Task>> methodCall, string queue);
    string Schedule<T>(Expression<Action<T>> methodCall, TimeSpan delay);
    string Schedule<T>(Expression<Func<T, Task>> methodCall, TimeSpan delay);
    string Schedule<T>(Expression<Action<T>> methodCall, DateTimeOffset enqueueAt);
    string Schedule<T>(Expression<Func<T, Task>> methodCall, DateTimeOffset enqueueAt);
    void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Action<T>> methodCall, string cronExpression);
    void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Func<T, Task>> methodCall, string cronExpression);
    void RemoveRecurring(string recurringJobId);
    void TriggerRecurring(string recurringJobId);
    bool Delete(string jobId);
}

using System.Linq.Expressions;

namespace AuthSamples.Platform.BackgroundJobs.Abstractions;

/// <summary>
/// Service for managing background jobs (fire-and-forget, delayed, recurring).
/// </summary>
public interface IBackgroundJobService
{
    /// <summary>
    /// Enqueues a job to be executed immediately in the background.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="methodCall">Expression representing the method to call.</param>
    /// <returns>The unique identifier of the created job.</returns>
    string Enqueue<T>(Expression<Action<T>> methodCall);

    /// <summary>
    /// Enqueues an async job to be executed immediately in the background.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="methodCall">Expression representing the async method to call.</param>
    /// <returns>The unique identifier of the created job.</returns>
    string Enqueue<T>(Expression<Func<T, Task>> methodCall);

    /// <summary>
    /// Schedules a job to be executed after a specified delay.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="methodCall">Expression representing the method to call.</param>
    /// <param name="delay">The time to wait before executing the job.</param>
    /// <returns>The unique identifier of the created job.</returns>
    string Schedule<T>(Expression<Action<T>> methodCall, TimeSpan delay);

    /// <summary>
    /// Schedules an async job to be executed after a specified delay.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="methodCall">Expression representing the async method to call.</param>
    /// <param name="delay">The time to wait before executing the job.</param>
    /// <returns>The unique identifier of the created job.</returns>
    string Schedule<T>(Expression<Func<T, Task>> methodCall, TimeSpan delay);

    /// <summary>
    /// Schedules a job to be executed at a specific time.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="methodCall">Expression representing the method to call.</param>
    /// <param name="enqueueAt">The specific time to execute the job.</param>
    /// <returns>The unique identifier of the created job.</returns>
    string Schedule<T>(Expression<Action<T>> methodCall, DateTimeOffset enqueueAt);

    /// <summary>
    /// Schedules an async job to be executed at a specific time.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="methodCall">Expression representing the async method to call.</param>
    /// <param name="enqueueAt">The specific time to execute the job.</param>
    /// <returns>The unique identifier of the created job.</returns>
    string Schedule<T>(Expression<Func<T, Task>> methodCall, DateTimeOffset enqueueAt);

    /// <summary>
    /// Creates or updates a recurring job with the specified cron expression.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="recurringJobId">The unique identifier for the recurring job.</param>
    /// <param name="methodCall">Expression representing the method to call.</param>
    /// <param name="cronExpression">Cron expression defining the schedule.</param>
    void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Action<T>> methodCall, string cronExpression);

    /// <summary>
    /// Creates or updates a recurring async job with the specified cron expression.
    /// </summary>
    /// <typeparam name="T">The type containing the method to execute.</typeparam>
    /// <param name="recurringJobId">The unique identifier for the recurring job.</param>
    /// <param name="methodCall">Expression representing the async method to call.</param>
    /// <param name="cronExpression">Cron expression defining the schedule.</param>
    void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Func<T, Task>> methodCall, string cronExpression);

    /// <summary>
    /// Removes a recurring job.
    /// </summary>
    /// <param name="recurringJobId">The unique identifier of the recurring job to remove.</param>
    void RemoveRecurring(string recurringJobId);

    /// <summary>
    /// Triggers an immediate execution of a recurring job.
    /// </summary>
    /// <param name="recurringJobId">The unique identifier of the recurring job to trigger.</param>
    void TriggerRecurring(string recurringJobId);

    /// <summary>
    /// Deletes a background job.
    /// </summary>
    /// <param name="jobId">The unique identifier of the job to delete.</param>
    /// <returns>True if the job was deleted; otherwise, false.</returns>
    bool Delete(string jobId);
}

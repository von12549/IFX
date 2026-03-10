using System.Linq.Expressions;
using IFX.Platform.BackgroundJobs.Infrastructure.Hangfire;
using Hangfire;
using Hangfire.Common;
using Hangfire.States;
using Moq;

namespace IFX.Platform.BackgroundJobs.Tests;

public class HangfireBackgroundJobServiceTests
{
    private readonly Mock<IBackgroundJobClient> _mockJobClient;
    private readonly Mock<IRecurringJobManager> _mockRecurringJobManager;
    private readonly HangfireBackgroundJobService _sut;

    public HangfireBackgroundJobServiceTests()
    {
        _mockJobClient = new Mock<IBackgroundJobClient>();
        _mockRecurringJobManager = new Mock<IRecurringJobManager>();
        _sut = new HangfireBackgroundJobService(_mockJobClient.Object, _mockRecurringJobManager.Object);
    }

    #region Enqueue Tests

    [Fact]
    public void Enqueue_WithSyncAction_CallsBackgroundJobClient()
    {
        // Arrange
        const string expectedJobId = "job-123";
        _mockJobClient
            .Setup(x => x.Create(It.IsAny<Job>(), It.IsAny<IState>()))
            .Returns(expectedJobId);

        // Act
        var jobId = _sut.Enqueue<ITestService>(x => x.DoWork());

        // Assert
        Assert.Equal(expectedJobId, jobId);
        _mockJobClient.Verify(x => x.Create(It.IsAny<Job>(), It.IsAny<EnqueuedState>()), Times.Once);
    }

    [Fact]
    public void Enqueue_WithAsyncAction_CallsBackgroundJobClient()
    {
        // Arrange
        const string expectedJobId = "job-456";
        _mockJobClient
            .Setup(x => x.Create(It.IsAny<Job>(), It.IsAny<IState>()))
            .Returns(expectedJobId);

        // Act
        var jobId = _sut.Enqueue<ITestService>(x => x.DoWorkAsync());

        // Assert
        Assert.Equal(expectedJobId, jobId);
        _mockJobClient.Verify(x => x.Create(It.IsAny<Job>(), It.IsAny<EnqueuedState>()), Times.Once);
    }

    #endregion

    #region Schedule Tests

    [Fact]
    public void Schedule_WithTimeSpan_CallsBackgroundJobClient()
    {
        // Arrange
        const string expectedJobId = "scheduled-job-123";
        var delay = TimeSpan.FromMinutes(30);
        _mockJobClient
            .Setup(x => x.Create(It.IsAny<Job>(), It.IsAny<IState>()))
            .Returns(expectedJobId);

        // Act
        var jobId = _sut.Schedule<ITestService>(x => x.DoWork(), delay);

        // Assert
        Assert.Equal(expectedJobId, jobId);
        _mockJobClient.Verify(
            x => x.Create(It.IsAny<Job>(), It.Is<ScheduledState>(s => s.EnqueueAt > DateTime.UtcNow)),
            Times.Once);
    }

    [Fact]
    public void Schedule_WithDateTimeOffset_CallsBackgroundJobClient()
    {
        // Arrange
        const string expectedJobId = "scheduled-job-456";
        var enqueueAt = DateTimeOffset.UtcNow.AddHours(1);
        _mockJobClient
            .Setup(x => x.Create(It.IsAny<Job>(), It.IsAny<IState>()))
            .Returns(expectedJobId);

        // Act
        var jobId = _sut.Schedule<ITestService>(x => x.DoWork(), enqueueAt);

        // Assert
        Assert.Equal(expectedJobId, jobId);
        _mockJobClient.Verify(x => x.Create(It.IsAny<Job>(), It.IsAny<ScheduledState>()), Times.Once);
    }

    [Fact]
    public void Schedule_AsyncWithTimeSpan_CallsBackgroundJobClient()
    {
        // Arrange
        const string expectedJobId = "scheduled-async-job";
        var delay = TimeSpan.FromHours(2);
        _mockJobClient
            .Setup(x => x.Create(It.IsAny<Job>(), It.IsAny<IState>()))
            .Returns(expectedJobId);

        // Act
        var jobId = _sut.Schedule<ITestService>(x => x.DoWorkAsync(), delay);

        // Assert
        Assert.Equal(expectedJobId, jobId);
        _mockJobClient.Verify(x => x.Create(It.IsAny<Job>(), It.IsAny<ScheduledState>()), Times.Once);
    }

    #endregion

    #region Recurring Job Tests

    [Fact]
    public void AddOrUpdateRecurring_WithSyncAction_CallsRecurringJobManager()
    {
        // Arrange
        const string recurringJobId = "daily-cleanup";
        const string cronExpression = "0 0 * * *"; // Daily at midnight

        // Act
        _sut.AddOrUpdateRecurring<ITestService>(recurringJobId, x => x.DoWork(), cronExpression);

        // Assert
        _mockRecurringJobManager.Verify(
            x => x.AddOrUpdate(
                recurringJobId,
                It.IsAny<Job>(),
                cronExpression,
                It.IsAny<RecurringJobOptions>()),
            Times.Once);
    }

    [Fact]
    public void AddOrUpdateRecurring_WithAsyncAction_CallsRecurringJobManager()
    {
        // Arrange
        const string recurringJobId = "hourly-sync";
        const string cronExpression = "0 * * * *"; // Every hour

        // Act
        _sut.AddOrUpdateRecurring<ITestService>(recurringJobId, x => x.DoWorkAsync(), cronExpression);

        // Assert
        _mockRecurringJobManager.Verify(
            x => x.AddOrUpdate(
                recurringJobId,
                It.IsAny<Job>(),
                cronExpression,
                It.IsAny<RecurringJobOptions>()),
            Times.Once);
    }

    [Fact]
    public void RemoveRecurring_CallsRecurringJobManager()
    {
        // Arrange
        const string recurringJobId = "job-to-remove";

        // Act
        _sut.RemoveRecurring(recurringJobId);

        // Assert
        _mockRecurringJobManager.Verify(x => x.RemoveIfExists(recurringJobId), Times.Once);
    }

    [Fact]
    public void TriggerRecurring_CallsRecurringJobManager()
    {
        // Arrange
        const string recurringJobId = "job-to-trigger";

        // Act
        _sut.TriggerRecurring(recurringJobId);

        // Assert
        _mockRecurringJobManager.Verify(x => x.Trigger(recurringJobId), Times.Once);
    }

    #endregion

    #region Delete Tests

    [Fact]
    public void Delete_WhenJobExists_ReturnsTrue()
    {
        // Arrange
        const string jobId = "job-to-delete";
        _mockJobClient
            .Setup(x => x.ChangeState(jobId, It.IsAny<DeletedState>(), null))
            .Returns(true);

        // Act
        var result = _sut.Delete(jobId);

        // Assert
        Assert.True(result);
        _mockJobClient.Verify(x => x.ChangeState(jobId, It.IsAny<DeletedState>(), null), Times.Once);
    }

    [Fact]
    public void Delete_WhenJobNotExists_ReturnsFalse()
    {
        // Arrange
        const string jobId = "non-existent-job";
        _mockJobClient
            .Setup(x => x.ChangeState(jobId, It.IsAny<DeletedState>(), null))
            .Returns(false);

        // Act
        var result = _sut.Delete(jobId);

        // Assert
        Assert.False(result);
    }

    #endregion

    // Test service interface for mocking
    public interface ITestService
    {
        void DoWork();
        Task DoWorkAsync();
    }
}

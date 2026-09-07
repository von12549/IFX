using IFX.BuildingBlocks.Application.Behaviors;
using IFX.BuildingBlocks.Application.Commands;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Results;
using IFX.BuildingBlocks.Application.Transactions;
using MediatR;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.BuildingBlocks.Application.Tests;

public sealed class TransactionBehaviorTests
{
    [Fact]
    public async Task Deferred_success_persists_once_then_dispatches()
    {
        var timeline = new List<string>();
        var executor = new RecordingExecutor(timeline);
        var participant = new RecordingParticipant(timeline);
        var buffer = new RecordingBuffer(timeline);
        var behavior = CreateBehavior<DeferredCommand>(executor, buffer, participant);
        var handlerCalls = 0;

        var result = await behavior.Handle(
            new DeferredCommand(),
            () =>
            {
                handlerCalls++;
                timeline.Add("handler");
                return Task.FromResult(TestResult.Success());
            },
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        handlerCalls.Should().Be(1);
        executor.PersistenceCalls.Should().Be(1);
        executor.AtomicCalls.Should().Be(0);
        timeline.Should().Equal("handler", "begin-persistence", "participant", "commit", "dispatch");
    }

    [Fact]
    public async Task Deferred_failure_discards_without_persisting_or_dispatching()
    {
        var timeline = new List<string>();
        var executor = new RecordingExecutor(timeline);
        var buffer = new RecordingBuffer(timeline);
        var behavior = CreateBehavior<DeferredCommand>(executor, buffer);

        var result = await behavior.Handle(
            new DeferredCommand(),
            () => Task.FromResult(TestResult.Failure()),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        executor.PersistenceCalls.Should().Be(0);
        executor.DiscardCalls.Should().Be(1);
        buffer.DispatchCalls.Should().Be(0);
        buffer.ClearCalls.Should().Be(1);
    }

    [Fact]
    public async Task Unexpected_exception_propagates_and_clears_pending_events()
    {
        var expected = new InvalidOperationException("internal detail");
        var executor = new RecordingExecutor([]);
        var buffer = new RecordingBuffer([]);
        var behavior = CreateBehavior<DeferredCommand>(executor, buffer);

        Func<Task> act = async () => await behavior.Handle(
            new DeferredCommand(),
            () => Task.FromException<TestResult>(expected),
            CancellationToken.None);

        (await act.Should().ThrowAsync<InvalidOperationException>()).Which.Should().BeSameAs(expected);
        executor.PersistenceCalls.Should().Be(0);
        buffer.ClearCalls.Should().Be(1);
    }

    [Fact]
    public async Task Cancellation_propagates_without_becoming_a_failure_result()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var expected = new OperationCanceledException(cancellation.Token);
        var executor = new RecordingExecutor([]);
        var buffer = new RecordingBuffer([]);
        var behavior = CreateBehavior<DeferredCommand>(executor, buffer);

        Func<Task> act = async () => await behavior.Handle(
            new DeferredCommand(),
            () => Task.FromException<TestResult>(expected),
            cancellation.Token);

        (await act.Should().ThrowAsync<OperationCanceledException>()).Which.Should().BeSameAs(expected);
        executor.PersistenceCalls.Should().Be(0);
        buffer.ClearCalls.Should().Be(1);
    }

    [Fact]
    public async Task Inbox_profile_runs_handler_and_participant_inside_atomic_transaction()
    {
        var timeline = new List<string>();
        var executor = new RecordingExecutor(timeline);
        var buffer = new RecordingBuffer(timeline);
        var behavior = CreateBehavior<InboxCommand>(executor, buffer, new RecordingParticipant(timeline));

        await behavior.Handle(
            new InboxCommand(),
            () =>
            {
                timeline.Add("handler");
                return Task.FromResult(TestResult.Success());
            },
            CancellationToken.None);

        executor.AtomicCalls.Should().Be(1);
        executor.PersistenceCalls.Should().Be(0);
        timeline.Should().Equal("begin-atomic", "handler", "participant", "commit", "dispatch");
    }

    [Fact]
    public async Task Inbox_failure_rolls_back_semantically_and_does_not_dispatch()
    {
        var executor = new RecordingExecutor([]);
        var buffer = new RecordingBuffer([]);
        var behavior = CreateBehavior<InboxCommand>(executor, buffer);

        var result = await behavior.Handle(
            new InboxCommand(),
            () => Task.FromResult(TestResult.Failure()),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        executor.AtomicCalls.Should().Be(1);
        executor.DiscardCalls.Should().Be(1);
        buffer.DispatchCalls.Should().Be(0);
        buffer.ClearCalls.Should().Be(1);
    }

    [Fact]
    public async Task Query_bypasses_transaction_resolution()
    {
        var resolver = new Mock<ITransactionExecutorResolver>(MockBehavior.Strict);
        var buffer = new RecordingBuffer([]);
        var behavior = new TransactionBehavior<TestQuery, string>(
            resolver.Object,
            buffer,
            NullLogger<TransactionBehavior<TestQuery, string>>.Instance);

        var result = await behavior.Handle(
            new TestQuery(),
            () => Task.FromResult("ok"),
            CancellationToken.None);

        result.Should().Be("ok");
        resolver.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Resolution_failure_happens_before_handler_execution()
    {
        var resolver = new Mock<ITransactionExecutorResolver>();
        resolver.Setup(r => r.Resolve(typeof(DeferredCommand), typeof(TestOwner)))
            .Throws(new TransactionOwnerResolutionException(typeof(DeferredCommand), typeof(TestOwner), 0));
        var behavior = new TransactionBehavior<DeferredCommand, TestResult>(
            resolver.Object,
            new RecordingBuffer([]),
            NullLogger<TransactionBehavior<DeferredCommand, TestResult>>.Instance);
        var handlerCalls = 0;

        Func<Task> act = async () => await behavior.Handle(
            new DeferredCommand(),
            () =>
            {
                handlerCalls++;
                return Task.FromResult(TestResult.Success());
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<TransactionOwnerResolutionException>();
        handlerCalls.Should().Be(0);
    }

    [Fact]
    public async Task Persistence_retry_reprepares_records_without_rerunning_handler_or_dispatch()
    {
        var timeline = new List<string>();
        var executor = new RetryingRecordingExecutor(timeline);
        var participant = new RecordingParticipant(timeline);
        var buffer = new RecordingBuffer(timeline);
        var resolver = new Mock<ITransactionExecutorResolver>();
        resolver.Setup(r => r.Resolve(typeof(DeferredCommand), typeof(TestOwner))).Returns(executor);
        resolver.Setup(r => r.ResolveParticipants(typeof(TestOwner))).Returns([participant]);
        var behavior = new TransactionBehavior<DeferredCommand, TestResult>(
            resolver.Object,
            buffer,
            NullLogger<TransactionBehavior<DeferredCommand, TestResult>>.Instance);
        var handlerCalls = 0;

        await behavior.Handle(
            new DeferredCommand(),
            () =>
            {
                handlerCalls++;
                timeline.Add("handler");
                return Task.FromResult(TestResult.Success());
            },
            CancellationToken.None);

        handlerCalls.Should().Be(1);
        executor.PersistenceAttempts.Should().Be(2);
        buffer.DispatchCalls.Should().Be(1);
        timeline.Should().Equal("handler", "attempt-1", "participant", "attempt-2", "participant", "commit", "dispatch");
    }

    private static TransactionBehavior<TCommand, TestResult> CreateBehavior<TCommand>(
        RecordingExecutor executor,
        RecordingBuffer buffer,
        params ITransactionParticipant[] participants)
        where TCommand : notnull, ICommand<TestResult>
    {
        var resolver = new Mock<ITransactionExecutorResolver>();
        resolver.Setup(r => r.Resolve(typeof(TCommand), typeof(TestOwner))).Returns(executor);
        resolver.Setup(r => r.ResolveParticipants(typeof(TestOwner))).Returns(participants);
        return new TransactionBehavior<TCommand, TestResult>(
            resolver.Object,
            buffer,
            NullLogger<TransactionBehavior<TCommand, TestResult>>.Instance);
    }

    private sealed record DeferredCommand : ICommand<TestResult, TestOwner>;

    private sealed record InboxCommand : ICommand<TestResult, TestOwner>
    {
        public TransactionProfile TransactionProfile => TransactionProfile.Inbox;
    }

    private sealed record TestQuery : IRequest<string>;

    private sealed class TestOwner : ITransactionOwner;

    private sealed record TestResult(bool IsSuccess, OperationErrorCategory ErrorCategory) : IOperationResult
    {
        public static TestResult Success() => new(true, OperationErrorCategory.None);

        public static TestResult Failure() => new(false, OperationErrorCategory.BusinessRule);
    }

    private sealed class RecordingExecutor(List<string> timeline) : ITransactionExecutor
    {
        public Type OwnerType => typeof(TestOwner);

        public int PersistenceCalls { get; private set; }

        public int AtomicCalls { get; private set; }

        public int DiscardCalls { get; private set; }

        public async Task ExecutePersistenceAsync(
            Func<CancellationToken, Task> prepareAsync,
            CancellationToken cancellationToken)
        {
            PersistenceCalls++;
            timeline.Add("begin-persistence");
            await prepareAsync(cancellationToken);
            timeline.Add("commit");
        }

        public async Task ExecuteAtomicAsync(
            Func<CancellationToken, Task> operationAsync,
            CancellationToken cancellationToken)
        {
            AtomicCalls++;
            timeline.Add("begin-atomic");
            await operationAsync(cancellationToken);
            timeline.Add("commit");
        }

        public ValueTask DiscardChangesAsync(CancellationToken cancellationToken)
        {
            DiscardCalls++;
            timeline.Add("discard");
            return ValueTask.CompletedTask;
        }
    }

    private sealed class RecordingParticipant(List<string> timeline) : ITransactionParticipant
    {
        public Task PrepareAsync(object command, object? response, CancellationToken cancellationToken)
        {
            timeline.Add("participant");
            return Task.CompletedTask;
        }
    }

    private sealed class RetryingRecordingExecutor(List<string> timeline) : ITransactionExecutor
    {
        public Type OwnerType => typeof(TestOwner);

        public int PersistenceAttempts { get; private set; }

        public async Task ExecutePersistenceAsync(
            Func<CancellationToken, Task> prepareAsync,
            CancellationToken cancellationToken)
        {
            // Models a relational execution strategy replaying only the persistence unit.
            for (var attempt = 1; attempt <= 2; attempt++)
            {
                PersistenceAttempts++;
                timeline.Add($"attempt-{attempt}");
                await prepareAsync(cancellationToken);
            }

            timeline.Add("commit");
        }

        public Task ExecuteAtomicAsync(
            Func<CancellationToken, Task> operationAsync,
            CancellationToken cancellationToken) => operationAsync(cancellationToken);

        public ValueTask DiscardChangesAsync(CancellationToken cancellationToken) => ValueTask.CompletedTask;
    }

    private sealed class RecordingBuffer(List<string> timeline) : ICommittedEventBuffer
    {
        public int DispatchCalls { get; private set; }

        public int ClearCalls { get; private set; }

        public void Add<TEvent>(TEvent @event) where TEvent : notnull => timeline.Add("add");

        public Task DispatchAfterCommitAsync(CancellationToken cancellationToken)
        {
            DispatchCalls++;
            timeline.Add("dispatch");
            return Task.CompletedTask;
        }

        public void Clear()
        {
            ClearCalls++;
            timeline.Add("clear");
        }
    }
}

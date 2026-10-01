using IFX.ApiHost.Runtime;

namespace IFX.IntegrationTests.Runtime;

public sealed class RuntimeDrainCoordinatorTests
{
    [Fact]
    public async Task BeginDrain_AtomicallyRejectsNewWork_AndWaitsForExistingWork()
    {
        var lifecycle = new RuntimeLifecycle();
        var coordinator = new RuntimeDrainCoordinator(lifecycle);
        coordinator.TryBeginOperation(out var operation).Should().BeTrue();

        coordinator.BeginDrain();

        coordinator.AcceptingNewWork.Should().BeFalse();
        coordinator.DrainToken.IsCancellationRequested.Should().BeTrue();
        lifecycle.Snapshot.State.Should().Be(RuntimeLifecycleState.Stopping);
        coordinator.TryBeginOperation(out _).Should().BeFalse();

        // The bound only guards against a hang; it must not measure thread-pool scheduling (IFX-V4-005).
        var wait = coordinator.WaitForIdleAsync(TimeSpan.FromSeconds(30), CancellationToken.None);
        wait.IsCompleted.Should().BeFalse();
        operation!.Dispose();
        (await wait).Should().BeTrue();
    }

    [Fact]
    public async Task WaitForIdleAsync_ReportsIdle_WhenIdleWinsUnderParallelLoad()
    {
        // IFX-V4-005 load check: every drained wait whose operation ends well inside the bound reports idle. It does
        // not force the thread-pool ordering of the race, so it passes on the unfixed coordinator as well.
        var results = await Task.WhenAll(Enumerable.Range(0, 500).Select(_ => Task.Run(async () =>
        {
            var coordinator = new RuntimeDrainCoordinator(new RuntimeLifecycle());
            coordinator.TryBeginOperation(out var operation).Should().BeTrue();
            coordinator.BeginDrain();
            var wait = coordinator.WaitForIdleAsync(TimeSpan.FromSeconds(5), CancellationToken.None);
            operation!.Dispose();
            return await wait;
        })));

        results.Should().HaveCount(500).And.OnlyContain(idle => idle);
    }

    [Fact]
    public async Task WaitForIdleAsync_TimesOutWithoutGuessingCompletion()
    {
        var coordinator = new RuntimeDrainCoordinator(new RuntimeLifecycle());
        coordinator.TryBeginOperation(out var operation).Should().BeTrue();
        coordinator.BeginDrain();

        (await coordinator.WaitForIdleAsync(TimeSpan.FromMilliseconds(10), CancellationToken.None))
            .Should().BeFalse();
        coordinator.InFlight.Should().Be(1);

        operation!.Dispose();
    }

    [Fact]
    public void DrainBudgets_MustBeStrictlyIncreasing()
    {
        var options = new RuntimeDrainOptions
        {
            OperationBudget = TimeSpan.FromSeconds(20),
            HandlerBudget = TimeSpan.FromSeconds(10)
        };

        var action = options.Validate;
        action.Should().Throw<InvalidOperationException>()
            .WithMessage("G04-DRAIN-BUDGET-INVALID*");
    }

    [Fact]
    public void StoppingLifecycle_CannotRaceBackToReady()
    {
        var lifecycle = new RuntimeLifecycle();
        lifecycle.MarkStopping();

        lifecycle.MarkReady();

        lifecycle.Snapshot.State.Should().Be(RuntimeLifecycleState.Stopping);
        lifecycle.Snapshot.ReasonCode.Should().Be("G04-STOPPING");
    }
}

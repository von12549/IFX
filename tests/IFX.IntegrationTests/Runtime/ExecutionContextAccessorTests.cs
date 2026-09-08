using IFX.ApiHost.Runtime;
using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;

namespace IFX.IntegrationTests.Runtime;

public sealed class ExecutionContextAccessorTests
{
    private readonly ExecutionContextAccessor _accessor = new();

    [Fact]
    public void Current_fails_when_no_trusted_context_is_active()
    {
        _accessor.HasCurrent.Should().BeFalse();

        var act = () => _accessor.Current;

        act.Should().Throw<InvalidOperationException>()
            .WithMessage("*No trusted execution context*");
    }

    [Fact]
    public void Push_and_disposal_bound_the_context_lifetime()
    {
        var context = CreateContext();

        using (_accessor.Push(context))
        {
            _accessor.HasCurrent.Should().BeTrue();
            _accessor.Current.Should().BeSameAs(context);
        }

        _accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public void Nested_scopes_restore_the_parent_context()
    {
        var parent = CreateContext();
        var child = CreateContext(causationId: CausationId.From(parent.OperationId));

        using (_accessor.Push(parent))
        {
            using (_accessor.Push(child))
            {
                _accessor.Current.Should().BeSameAs(child);
            }

            _accessor.Current.Should().BeSameAs(parent);
        }

        _accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public async Task Parallel_tenant_scopes_do_not_cross_talk()
    {
        var contexts = Enumerable.Range(0, 8).Select(_ => CreateContext()).ToArray();

        var observed = await Task.WhenAll(contexts.Select(context => Task.Run(async () =>
        {
            using (_accessor.Push(context))
            {
                await Task.Yield();
                _accessor.Current.Should().BeSameAs(context);
                return _accessor.Current.Scope.RequireTenant().TenantId;
            }
        })));

        observed.Should().Equal(contexts.Select(context => context.Scope.RequireTenant().TenantId));
        _accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public async Task RunAsync_cleans_up_after_an_exception()
    {
        var context = CreateContext();

        Func<Task> act = () => _accessor.RunAsync(
            context,
            _ => throw new InvalidOperationException("probe"));

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("probe");
        _accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public async Task RunAsync_cleans_up_after_cancellation()
    {
        var context = CreateContext();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        Func<Task> act = () => _accessor.RunAsync(
            context,
            token => Task.FromCanceled(token),
            cancellation.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
        _accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public async Task Detached_work_does_not_capture_the_active_context()
    {
        var context = CreateContext();
        bool observedContext;

        using (_accessor.Push(context))
        {
            observedContext = await ObserveDetachedContextAsync();
            _accessor.Current.Should().BeSameAs(context);
        }

        observedContext.Should().BeFalse();
        _accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public void Out_of_order_disposal_fails_and_can_then_be_cleaned_up_in_order()
    {
        var parent = _accessor.Push(CreateContext());
        var child = _accessor.Push(CreateContext());

        var act = parent.Dispose;

        act.Should().Throw<InvalidOperationException>().WithMessage("*reverse order*");
        child.Dispose();
        parent.Dispose();
        _accessor.HasCurrent.Should().BeFalse();
    }

    private async Task<bool> ObserveDetachedContextAsync()
    {
        var observed = false;
        await _accessor.RunDetachedAsync(_ =>
        {
            observed = _accessor.HasCurrent;
            return Task.CompletedTask;
        });
        return observed;
    }

    private static ExecutionContextSnapshot CreateContext(CausationId? causationId = null) => new(
        CorrelationId.New(),
        OperationId.New(),
        causationId,
        ExecutionScope.ForTenant(new TenantScope(Guid.NewGuid())),
        new ActorReference(ActorKind.User, Guid.NewGuid().ToString("D")),
        new SourceReference("ifx", "test", 1));
}

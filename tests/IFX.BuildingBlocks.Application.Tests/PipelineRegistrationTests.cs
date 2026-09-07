using IFX.BuildingBlocks.Application.Behaviors;
using IFX.BuildingBlocks.Application.Transactions;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.BuildingBlocks.Application.Tests;

public sealed class PipelineRegistrationTests
{
    [Fact]
    public void Registers_each_shared_behavior_once_in_the_required_order()
    {
        var services = new ServiceCollection();

        services.AddApplicationPipeline();

        var behaviors = services
            .Where(descriptor => descriptor.ServiceType == typeof(IPipelineBehavior<,>))
            .Select(descriptor => descriptor.ImplementationType)
            .ToArray();
        behaviors.Should().Equal(
            typeof(LoggingBehavior<,>),
            typeof(ValidationBehavior<,>),
            typeof(TransactionBehavior<,>));
    }

    [Fact]
    public void Duplicate_pipeline_registration_fails_fast()
    {
        var services = new ServiceCollection();
        services.AddApplicationPipeline();

        Action act = () => services.AddApplicationPipeline();

        act.Should().Throw<InvalidOperationException>()
            .WithMessage("*only be registered once*");
    }

    [Fact]
    public void Multiple_executors_for_one_owner_fail_fast()
    {
        var services = new ServiceCollection();
        services.AddApplicationPipeline();
        services.AddKeyedScoped<ITransactionExecutor, StubExecutor>(typeof(TestOwner));
        services.AddKeyedScoped<ITransactionExecutor, StubExecutor>(typeof(TestOwner));
        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();

        Action act = () => scope.ServiceProvider
            .GetRequiredService<ITransactionExecutorResolver>()
            .Resolve(typeof(string), typeof(TestOwner));

        act.Should().Throw<TransactionOwnerResolutionException>()
            .Where(exception => exception.CandidateCount == 2);
    }

    private sealed class TestOwner : ITransactionOwner;

    private sealed class StubExecutor : ITransactionExecutor
    {
        public Type OwnerType => typeof(TestOwner);

        public Task ExecutePersistenceAsync(Func<CancellationToken, Task> prepareAsync, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task ExecuteAtomicAsync(Func<CancellationToken, Task> operationAsync, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public ValueTask DiscardChangesAsync(CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }
}

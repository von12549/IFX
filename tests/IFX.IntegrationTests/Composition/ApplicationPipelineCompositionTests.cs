using IFX.BuildingBlocks.Application.Behaviors;
using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.IntegrationTests.Fixtures;
using IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.CreateTenant;
using IFX.Modules.IAM.Application.Identity.Queries.GetAllIdps;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.Holdings.Application.Transactions;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Transaction.Application.Transactions;
using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace IFX.IntegrationTests.Composition;

public sealed class ApplicationPipelineCompositionTests(CustomWebApplicationFactory factory)
    : IClassFixture<CustomWebApplicationFactory>
{
    [Fact]
    public void Real_ApiHost_exposes_one_execution_context_owner_through_both_ports()
    {
        var accessors = factory.Services.GetServices<IExecutionContextAccessor>().ToArray();
        var factories = factory.Services.GetServices<IExecutionContextScopeFactory>().ToArray();
        var concrete = factory.Services.GetRequiredService<IFX.ApiHost.Runtime.ExecutionContextAccessor>();

        accessors.Should().ContainSingle().Which.Should().BeSameAs(concrete);
        factories.Should().ContainSingle().Which.Should().BeSameAs(concrete);
        concrete.HasCurrent.Should().BeFalse();
    }

    [Theory]
    [InlineData(typeof(CreateTenantCommand))]
    [InlineData(typeof(GetAllIdpsQuery))]
    public void Real_ApiHost_resolves_one_shared_pipeline_in_required_order(Type requestType)
    {
        using var scope = factory.Services.CreateScope();
        var responseType = requestType.GetInterfaces()
            .Single(type => type.IsGenericType && type.GetGenericTypeDefinition() == typeof(IRequest<>))
            .GenericTypeArguments[0];
        var pipelineType = typeof(IPipelineBehavior<,>).MakeGenericType(requestType, responseType);

        var behaviors = scope.ServiceProvider.GetServices(pipelineType).ToArray();

        behaviors.Should().HaveCount(3);
        behaviors.Select(behavior => behavior!.GetType().GetGenericTypeDefinition()).Should().Equal(
            typeof(LoggingBehavior<,>),
            typeof(ValidationBehavior<,>),
            typeof(TransactionBehavior<,>));
    }

    [Theory]
    [InlineData(typeof(IamTransactionOwner), "IamTransactionExecutor")]
    [InlineData(typeof(CrmTransactionOwner), "CrmTransactionExecutor")]
    [InlineData(typeof(HoldingsTransactionOwner), "HoldingsTransactionExecutor")]
    [InlineData(typeof(RegistryTransactionOwner), "RegistryTransactionExecutor")]
    [InlineData(typeof(TransactionModuleOwner), "TransactionModuleExecutor")]
    public void Real_ApiHost_resolves_exactly_the_executor_keyed_to_each_module(
        Type ownerType,
        string expectedExecutorName)
    {
        using var scope = factory.Services.CreateScope();
        var resolver = scope.ServiceProvider.GetRequiredService<ITransactionExecutorResolver>();

        var executor = resolver.Resolve(typeof(CreateTenantCommand), ownerType);

        executor.OwnerType.Should().Be(ownerType);
        executor.GetType().Name.Should().Be(expectedExecutorName);
    }

    [Fact]
    public async Task Real_ApiHost_invokes_validation_handler_and_transaction_once_for_a_valid_command()
    {
        using var configured = CreateProbeHost();
        using var scope = configured.Services.CreateScope();
        var recorder = scope.ServiceProvider.GetRequiredService<ProbeRecorder>();

        var result = await scope.ServiceProvider.GetRequiredService<IMediator>()
            .Send(new PipelineProbeCommand("valid"));

        result.IsSuccess.Should().BeTrue();
        recorder.ValidatorCalls.Should().Be(1);
        recorder.HandlerCalls.Should().Be(1);
        recorder.PersistenceCalls.Should().Be(1);
    }

    [Fact]
    public async Task Real_ApiHost_invalid_command_never_enters_handler_or_transaction()
    {
        using var configured = CreateProbeHost();
        using var scope = configured.Services.CreateScope();
        var recorder = scope.ServiceProvider.GetRequiredService<ProbeRecorder>();

        Func<Task> act = () => scope.ServiceProvider.GetRequiredService<IMediator>()
            .Send(new PipelineProbeCommand(string.Empty));

        await act.Should().ThrowAsync<ValidationException>();
        recorder.ValidatorCalls.Should().Be(1);
        recorder.HandlerCalls.Should().Be(0);
        recorder.PersistenceCalls.Should().Be(0);
    }

    [Fact]
    public async Task Real_ApiHost_query_bypasses_every_transaction_executor()
    {
        using var configured = CreateProbeHost();
        using var scope = configured.Services.CreateScope();
        var recorder = scope.ServiceProvider.GetRequiredService<ProbeRecorder>();

        var result = await scope.ServiceProvider.GetRequiredService<IMediator>()
            .Send(new PipelineProbeQuery());

        result.Should().Be("ok");
        recorder.QueryHandlerCalls.Should().Be(1);
        recorder.PersistenceCalls.Should().Be(0);
    }

    [Fact]
    public async Task Five_module_commands_call_only_their_keyed_executor()
    {
        using var configured = CreateFiveOwnerProbeHost();
        using var scope = configured.Services.CreateScope();
        var recorder = scope.ServiceProvider.GetRequiredService<OwnerProbeRecorder>();
        var mediator = scope.ServiceProvider.GetRequiredService<IMediator>();

        await AssertOnlyOwnerCalledAsync<IamTransactionOwner>(mediator, recorder);
        await AssertOnlyOwnerCalledAsync<CrmTransactionOwner>(mediator, recorder);
        await AssertOnlyOwnerCalledAsync<HoldingsTransactionOwner>(mediator, recorder);
        await AssertOnlyOwnerCalledAsync<RegistryTransactionOwner>(mediator, recorder);
        await AssertOnlyOwnerCalledAsync<TransactionModuleOwner>(mediator, recorder);
    }

    private Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> CreateProbeHost() =>
        factory.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
        {
            services.AddSingleton<ProbeRecorder>();
            services.AddTransient<IRequestHandler<PipelineProbeCommand, ProbeResult>, PipelineProbeHandler>();
            services.AddTransient<IRequestHandler<PipelineProbeQuery, string>, PipelineProbeQueryHandler>();
            services.AddTransient<IValidator<PipelineProbeCommand>, PipelineProbeValidator>();
            services.AddKeyedScoped<ITransactionExecutor, PipelineProbeExecutor>(typeof(PipelineProbeOwner));
        }));

    private Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> CreateFiveOwnerProbeHost() =>
        factory.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
        {
            services.AddSingleton<OwnerProbeRecorder>();
            services.AddTransient<
                IRequestHandler<OwnerProbeCommand<IamTransactionOwner>, ProbeResult>,
                OwnerProbeHandler<IamTransactionOwner>>();
            services.AddTransient<
                IRequestHandler<OwnerProbeCommand<CrmTransactionOwner>, ProbeResult>,
                OwnerProbeHandler<CrmTransactionOwner>>();
            services.AddTransient<
                IRequestHandler<OwnerProbeCommand<HoldingsTransactionOwner>, ProbeResult>,
                OwnerProbeHandler<HoldingsTransactionOwner>>();
            services.AddTransient<
                IRequestHandler<OwnerProbeCommand<RegistryTransactionOwner>, ProbeResult>,
                OwnerProbeHandler<RegistryTransactionOwner>>();
            services.AddTransient<
                IRequestHandler<OwnerProbeCommand<TransactionModuleOwner>, ProbeResult>,
                OwnerProbeHandler<TransactionModuleOwner>>();
            ReplaceExecutor<IamTransactionOwner>(services);
            ReplaceExecutor<CrmTransactionOwner>(services);
            ReplaceExecutor<HoldingsTransactionOwner>(services);
            ReplaceExecutor<RegistryTransactionOwner>(services);
            ReplaceExecutor<TransactionModuleOwner>(services);
        }));

    private static void ReplaceExecutor<TOwner>(IServiceCollection services)
        where TOwner : ITransactionOwner
    {
        services.RemoveAllKeyed<ITransactionExecutor>(typeof(TOwner));
        services.AddKeyedScoped<ITransactionExecutor, OwnerProbeExecutor<TOwner>>(typeof(TOwner));
    }

    private static async Task AssertOnlyOwnerCalledAsync<TOwner>(
        IMediator mediator,
        OwnerProbeRecorder recorder)
        where TOwner : ITransactionOwner
    {
        recorder.Reset();

        var result = await mediator.Send(new OwnerProbeCommand<TOwner>());

        result.IsSuccess.Should().BeTrue();
        recorder.Calls.Should().ContainSingle().Which.Should().Be(typeof(TOwner));
    }

    public sealed record PipelineProbeCommand(string Value)
        : IFX.BuildingBlocks.Application.Commands.ICommand<ProbeResult, PipelineProbeOwner>;

    public sealed record PipelineProbeQuery : IRequest<string>;

    public sealed record OwnerProbeCommand<TOwner> :
        IFX.BuildingBlocks.Application.Commands.ICommand<ProbeResult, TOwner>
        where TOwner : ITransactionOwner;

    public sealed record ProbeResult(bool IsSuccess, IFX.BuildingBlocks.Application.Results.OperationErrorCategory ErrorCategory)
        : IFX.BuildingBlocks.Application.Results.IOperationResult;

    public sealed class PipelineProbeOwner : ITransactionOwner;

    public sealed class ProbeRecorder
    {
        public int ValidatorCalls { get; set; }
        public int HandlerCalls { get; set; }
        public int QueryHandlerCalls { get; set; }
        public int PersistenceCalls { get; set; }
    }

    public sealed class OwnerProbeRecorder
    {
        public List<Type> Calls { get; } = [];

        public void Reset() => Calls.Clear();
    }

    public sealed class PipelineProbeValidator : AbstractValidator<PipelineProbeCommand>
    {
        public PipelineProbeValidator(ProbeRecorder recorder)
        {
            RuleFor(command => command.Value).Must(value =>
            {
                recorder.ValidatorCalls++;
                return !string.IsNullOrWhiteSpace(value);
            });
        }
    }

    public sealed class PipelineProbeHandler(ProbeRecorder recorder)
        : IRequestHandler<PipelineProbeCommand, ProbeResult>
    {
        public Task<ProbeResult> Handle(PipelineProbeCommand request, CancellationToken cancellationToken)
        {
            recorder.HandlerCalls++;
            return Task.FromResult(new ProbeResult(
                true,
                IFX.BuildingBlocks.Application.Results.OperationErrorCategory.None));
        }
    }

    public sealed class PipelineProbeQueryHandler(ProbeRecorder recorder)
        : IRequestHandler<PipelineProbeQuery, string>
    {
        public Task<string> Handle(PipelineProbeQuery request, CancellationToken cancellationToken)
        {
            recorder.QueryHandlerCalls++;
            return Task.FromResult("ok");
        }
    }

    public sealed class OwnerProbeHandler<TOwner>
        : IRequestHandler<OwnerProbeCommand<TOwner>, ProbeResult>
        where TOwner : ITransactionOwner
    {
        public Task<ProbeResult> Handle(
            OwnerProbeCommand<TOwner> request,
            CancellationToken cancellationToken) => Task.FromResult(new ProbeResult(
                true,
                IFX.BuildingBlocks.Application.Results.OperationErrorCategory.None));
    }

    public sealed class PipelineProbeExecutor(ProbeRecorder recorder) : ITransactionExecutor
    {
        public Type OwnerType => typeof(PipelineProbeOwner);

        public async Task ExecutePersistenceAsync(
            Func<CancellationToken, Task> prepareAsync,
            CancellationToken cancellationToken)
        {
            recorder.PersistenceCalls++;
            await prepareAsync(cancellationToken);
        }

        public Task ExecuteAtomicAsync(
            Func<CancellationToken, Task> operationAsync,
            CancellationToken cancellationToken) => operationAsync(cancellationToken);

        public ValueTask DiscardChangesAsync(CancellationToken cancellationToken) => ValueTask.CompletedTask;
    }

    public sealed class OwnerProbeExecutor<TOwner>(OwnerProbeRecorder recorder) : ITransactionExecutor
        where TOwner : ITransactionOwner
    {
        public Type OwnerType => typeof(TOwner);

        public async Task ExecutePersistenceAsync(
            Func<CancellationToken, Task> prepareAsync,
            CancellationToken cancellationToken)
        {
            recorder.Calls.Add(typeof(TOwner));
            await prepareAsync(cancellationToken);
        }

        public Task ExecuteAtomicAsync(
            Func<CancellationToken, Task> operationAsync,
            CancellationToken cancellationToken) => operationAsync(cancellationToken);

        public ValueTask DiscardChangesAsync(CancellationToken cancellationToken) => ValueTask.CompletedTask;
    }
}

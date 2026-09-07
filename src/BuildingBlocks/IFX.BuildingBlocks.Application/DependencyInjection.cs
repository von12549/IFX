using IFX.BuildingBlocks.Application.Behaviors;
using IFX.BuildingBlocks.Application.Transactions;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.BuildingBlocks.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplicationPipeline(this IServiceCollection services)
    {
        if (services.Any(descriptor => descriptor.ServiceType == typeof(ApplicationPipelineRegistration)))
        {
            throw new InvalidOperationException("The shared Application pipeline may only be registered once.");
        }

        services.AddSingleton<ApplicationPipelineRegistration>();
        services.AddScoped<ITransactionExecutorResolver, TransactionExecutorResolver>();
        services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
        services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
        services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));
        return services;
    }

    private sealed class ApplicationPipelineRegistration;
}

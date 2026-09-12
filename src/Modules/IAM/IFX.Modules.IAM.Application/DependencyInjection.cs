using System.Reflection;
using FluentValidation;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Services;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.IAM.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        var assembly = Assembly.GetExecutingAssembly();

        // Register MediatR
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(assembly));

        // Register AutoMapper
        services.AddAutoMapper(assembly);

        // Register FluentValidation validators
        services.AddValidatorsFromAssembly(assembly);
        services.AddScoped<IEmailVerificationIssuanceService, EmailVerificationIssuanceService>();

        return services;
    }
}

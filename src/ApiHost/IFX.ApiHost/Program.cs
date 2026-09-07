using App.Abstractions;
using IFX.BuildingBlocks.Application;
using IFX.ApiHost.Configuration;
using IFX.ApiHost.Middleware;
using IFX.Modules.Auth.Composition;
using IFX.Modules.CRM.Composition;
using IFX.Modules.Holdings.Composition;
using IFX.Modules.Transaction.Composition;
using IFX.Modules.Registry.Composition;
using IFX.ApiHost.Authorization;
using Microsoft.AspNetCore.Authorization;
using IFX.Platform.BackgroundJobs.Composition;
using IFX.Platform.Messaging.Composition;
using IFX.Platform.Notifications.Composition;
using Serilog;

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/auth-api-.log", rollingInterval: RollingInterval.Day)
    .Enrich.FromLogContext()
    .CreateLogger();

try
{
    Log.Information("Starting Auth API");

    var builder = WebApplication.CreateBuilder(args);

    // Add Serilog
    builder.Host.UseSerilog();

    // Register modules (each module registers its own services + IModuleInstaller)
    builder.Services.AddAuthModule(builder.Configuration);
    builder.Services.AddCrmModule(builder.Configuration);
    builder.Services.AddRegistryModule(builder.Configuration);
    builder.Services.AddHoldingsModule(builder.Configuration);
    builder.Services.AddTransactionModule(builder.Configuration);
    builder.Services.AddApplicationPipeline();

    // Register platform services
    builder.Services.AddMessaging();
    builder.Services.AddBackgroundJobs(builder.Configuration);
    builder.Services.AddNotificationsOptional(builder.Configuration);

    // Add API infrastructure (via configuration modules)
    builder.Services.AddOpaClient(builder.Configuration);
    builder.Services.AddAuthAuthentication(builder.Configuration);
    builder.Services.AddAuthSwagger();
    builder.Services.AddAuthCors();
    builder.Services.AddAuthHealthChecks(builder.Configuration);
    builder.Services.AddAuthorization();
    builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionAuthorizationPolicyProvider>();
    builder.Services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();

    var app = builder.Build();

    // Configure middleware pipeline
    app.UseMiddleware<RequestLoggingMiddleware>();
    app.UseMiddleware<ExceptionHandlingMiddleware>();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/swagger/auth/swagger.json",        "Auth");
            options.SwaggerEndpoint("/swagger/crm/swagger.json",         "CRM");
            options.SwaggerEndpoint("/swagger/registry/swagger.json",    "Registry");
            options.SwaggerEndpoint("/swagger/holdings/swagger.json",    "Holdings");
            options.SwaggerEndpoint("/swagger/transaction/swagger.json", "Transaction");
        });
    }

    app.UseHttpsRedirection();
    app.UseCors("AllowAll");
    app.UseAuthentication();
    app.UseAuthorization();

    // Background jobs dashboard
    app.UseBackgroundJobsDashboard();

    // Map endpoints
    app.MapAuthHealthCheckEndpoints();  // /health, /health/ready

    // Map module endpoints (via IModuleInstaller discovery)
    var installers = app.Services.GetServices<IModuleInstaller>();
    foreach (var installer in installers)
    {
        Log.Information("Mapping endpoints for {Module} module", installer.ModuleName);
        installer.MapEndpoints(app);
    }

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
    throw;
}
finally
{
    Log.CloseAndFlush();
}

// Needed for integration tests (WebApplicationFactory requires access to Program class)
public partial class Program { }

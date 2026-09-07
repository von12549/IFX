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
using IFX.ApiHost.Runtime;

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
    var runtimeProfile = RuntimeProfileResolver.Resolve(builder.Configuration, builder.Environment);
    builder.Services.AddSingleton(runtimeProfile);
    var runtimeInstanceIdentity = RuntimeInstanceIdentity.Create(runtimeProfile.Role);
    builder.Services.AddSingleton(runtimeInstanceIdentity);
    var runtimeManifests = RuntimeManifestLoader.Load(AppContext.BaseDirectory);
    builder.Services.AddSingleton(runtimeManifests.Modules);
    builder.Services.AddSingleton(runtimeManifests.Release);
    builder.Services.AddSingleton<RuntimeLifecycle>();
    builder.Services.AddSingleton<HealthSnapshotStore>();
    var drainOptions = builder.Configuration
        .GetSection(RuntimeDrainOptions.SectionName)
        .Get<RuntimeDrainOptions>() ?? new RuntimeDrainOptions();
    drainOptions.Validate();
    builder.Services.AddSingleton(drainOptions);
    builder.Services.AddSingleton<RuntimeDrainCoordinator>();
    builder.Services.AddSingleton<IFX.Platform.Messaging.Composition.Dispatching.IRuntimeDrainSignal>(
        services => services.GetRequiredService<RuntimeDrainCoordinator>());
    builder.Services.Configure<HostOptions>(options => options.ShutdownTimeout = drainOptions.ProcessGrace);

    // Add Serilog
    builder.Host.UseSerilog();

    // Register platform primitives before the required module topology.
    builder.Services.AddMessaging();
    builder.Services.AddBackgroundJobsClient(builder.Configuration);
    if (runtimeProfile.Capabilities.HangfireServer)
    {
        builder.Services.AddBackgroundJobsServer(builder.Configuration, runtimeInstanceIdentity.Value);
    }
    builder.Services.AddNotificationsOptional(builder.Configuration);

    // Register required modules. Composition registration is side-effect free.
    builder.Services.AddAuthModule(builder.Configuration);
    builder.Services.AddCrmModule(builder.Configuration);
    builder.Services.AddRegistryModule(builder.Configuration);
    builder.Services.AddHoldingsModule(builder.Configuration);
    builder.Services.AddTransactionModule(builder.Configuration);
    builder.Services.AddApplicationPipeline();

    // Add API infrastructure (via configuration modules)
    builder.Services.AddOpaClient(builder.Configuration);
    builder.Services.AddAuthAuthentication(builder.Configuration);
    builder.Services.AddAuthSwagger();
    builder.Services.AddAuthCors();
    builder.Services.AddAuthHealthChecks(builder.Configuration);
    builder.Services.AddAuthorization();
    builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionAuthorizationPolicyProvider>();
    builder.Services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
    builder.Services.AddHostedService<StartupDependencyMonitor>();
    builder.Services.AddHostedService<RuntimeDrainHostedService>();

    var app = builder.Build();
    var orderedInstallers = StartupBoundaryVerifier.ValidateComposition(
        app.Services.GetServices<IModuleInstaller>(),
        runtimeManifests.Modules,
        runtimeManifests.Release,
        runtimeProfile);

    // Configure middleware pipeline
    app.UseMiddleware<RequestLoggingMiddleware>();
    app.UseMiddleware<ExceptionHandlingMiddleware>();
    app.UseMiddleware<RuntimeDrainMiddleware>();

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
    if (runtimeProfile.Capabilities.HangfireServer)
    {
        app.UseBackgroundJobsDashboard();
    }

    // Map endpoints
    app.MapAuthHealthCheckEndpoints();

    app.MapGet("/management/runtime", (RuntimeProfile profile, RuntimeInstanceIdentity instance) => Results.Ok(new
    {
        role = profile.RoleName,
        instance = instance.Value,
        capabilities = profile.Capabilities
    })).RequireAuthorization();

    if (runtimeProfile.Capabilities.Api)
    {
        // Business endpoints are mapped only by api/all roles.
        foreach (var installer in orderedInstallers)
        {
            Log.Information("Mapping endpoints for {Module} module", installer.ModuleName);
            installer.MapEndpoints(app);
        }
    }

    StartupBoundaryVerifier.ValidateEndpointIdentity(app.Services.GetRequiredService<EndpointDataSource>());

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

using App.Abstractions;
using AuthSamples.ApiHost.Configuration;
using AuthSamples.ApiHost.Middleware;
using AuthSamples.Modules.Auth.Composition;
using AuthSamples.Platform.BackgroundJobs.Composition;
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

    // Register platform services
    builder.Services.AddBackgroundJobs(builder.Configuration);

    // Add API infrastructure (via configuration modules)
    builder.Services.AddAuthAuthentication(builder.Configuration);
    builder.Services.AddAuthSwagger();
    builder.Services.AddAuthCors();
    builder.Services.AddAuthHealthChecks(builder.Configuration);
    builder.Services.AddAuthorization();

    var app = builder.Build();

    // Apply EF Core migrations on startup (via IAppMigrator discovery)
    using (var scope = app.Services.CreateScope())
    {
        var sp = scope.ServiceProvider;

        try
        {
            var migrators = sp.GetServices<IAppMigrator>();

            foreach (var m in migrators)
            {
                Log.Information("Applying migrations for {Module}", m.Name);
                await m.MigrateAsync(sp);
                Log.Information("Migrations applied for {Module}", m.Name);
            }
        }
        catch (Exception ex)
        {
            Log.Error(ex, "An error occurred while migrating the database");
            throw;
        }
    }

    // Configure middleware pipeline
    app.UseMiddleware<RequestLoggingMiddleware>();
    app.UseMiddleware<ExceptionHandlingMiddleware>();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/swagger/v1/swagger.json", "Auth API v1");
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
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// Needed for integration tests (WebApplicationFactory requires access to Program class)
public partial class Program { }

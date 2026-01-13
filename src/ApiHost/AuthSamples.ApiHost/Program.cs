using AuthSamples.ApiHost.Configuration;
using AuthSamples.ApiHost.Middleware;
using AuthSamples.Modules.Auth.Infrastructure.Persistence;
using AuthSamples.Modules.Auth.Presentation;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using Serilog;
using AuthSamples.Modules.Auth.Composition;

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

    // Add layer services
    builder.Services.AddAuthModuleServices(builder.Configuration);

    // Add API infrastructure (via configuration modules)
    builder.Services.AddAuthAuthentication(builder.Configuration);
    builder.Services.AddAuthSwagger();
    builder.Services.AddAuthCors();
    builder.Services.AddAuthHealthChecks(builder.Configuration);
    builder.Services.AddAuthorization();
    var app = builder.Build();

    // Apply EF Core migrations on startup
    using (var scope = app.Services.CreateScope())
    {
        var services = scope.ServiceProvider;
        try
        {
            var context = services.GetRequiredService<AuthDbContext>();
            context.Database.Migrate();
            Log.Information("Database migrations applied successfully");
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

    // Map endpoints
    app.MapAuthHealthCheckEndpoints();  // /health, /health/ready
    // Map endpoints from modules
    app.MapAuthModuleEndpoints();

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

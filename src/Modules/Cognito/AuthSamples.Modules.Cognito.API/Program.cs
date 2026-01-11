using AuthSamples.Modules.Cognito.API.Authorization;
using AuthSamples.Modules.Cognito.API.HealthChecks;
using AuthSamples.Modules.Cognito.API.Middleware;
using AuthSamples.Modules.Cognito.Application;
using AuthSamples.Modules.Cognito.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;
using System.Text.Json;

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/cognito-api-.log", rollingInterval: RollingInterval.Day)
    .Enrich.FromLogContext()
    .CreateLogger();

try
{
    Log.Information("Starting Cognito API");

    var builder = WebApplication.CreateBuilder(args);

    // Add Serilog
    builder.Host.UseSerilog();

    // Add services to the container.
    builder.Services.AddApplicationServices();
    builder.Services.AddInfrastructureServices(builder.Configuration);

    // Add controllers
    builder.Services.AddControllers();

    // Configure CORS
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("AllowAll", policy =>
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        });
    });

    // Configure JWT Authentication
    var cognitoSettings = builder.Configuration.GetSection("CognitoSettings");
    var region = cognitoSettings["Region"];
    var userPoolId = cognitoSettings["UserPoolId"];
    var authority = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}";

    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.Authority = authority;
            options.MapInboundClaims = false;
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                ValidateIssuer = true,
                ValidateLifetime = true,
                ValidateAudience = false,
                NameClaimType = "sub"
            };
        });

    // Configure Claims Transformation (adds role claims from database)
    builder.Services.AddTransient<IClaimsTransformation, UserRoleClaimsTransformation>();

    // Configure Swagger/OpenAPI
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(options =>
    {
        options.SwaggerDoc("v1", new OpenApiInfo
        {
            Title = "Cognito Authentication API",
            Version = "v1",
            Description = "ASP.NET Core 8 API with AWS Cognito authentication and full audit trail"
        });

        // Add JWT Bearer authentication to Swagger
        options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token in the text input below.",
            Name = "Authorization",
            In = ParameterLocation.Header,
            Type = SecuritySchemeType.Http,
            Scheme = "Bearer",
            BearerFormat = "JWT"
        });

        options.AddSecurityRequirement(new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Type = ReferenceType.SecurityScheme,
                        Id = "Bearer"
                    }
                },
                Array.Empty<string>()
            }
        });
    });

    // Configure Health Checks
    var connectionString = builder.Configuration.GetConnectionString("CognitoDatabase");
    builder.Services.AddHealthChecks()
        .AddSqlServer(
            connectionString: connectionString!,
            healthQuery: "SELECT 1;",
            name: "SQL Server",
            failureStatus: HealthStatus.Unhealthy,
            tags: new[] { "database", "sqlserver" })
        .AddCheck<CognitoHealthCheck>(
            name: "AWS Cognito",
            failureStatus: HealthStatus.Unhealthy,
            tags: new[] { "aws", "cognito", "authentication" });

    var app = builder.Build();

    // Apply EF Core migrations on startup
    using (var scope = app.Services.CreateScope())
    {
        var services = scope.ServiceProvider;
        try
        {
            var context = services.GetRequiredService<AuthSamples.Modules.Cognito.Infrastructure.Persistence.CognitoDbContext>();
            context.Database.Migrate();
            Log.Information("Database migrations applied successfully");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "An error occurred while migrating the database");
            throw;
        }
    }

    // Configure the HTTP request pipeline.
    app.UseMiddleware<RequestLoggingMiddleware>();
    app.UseMiddleware<ExceptionHandlingMiddleware>();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/swagger/v1/swagger.json", "Cognito API v1");
        });
    }

    app.UseHttpsRedirection();
    app.UseCors("AllowAll");

    app.UseAuthentication();
    app.UseAuthorization();

    // Map Health Check Endpoints
    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        Predicate = _ => true,
        ResponseWriter = async (context, report) =>
        {
            context.Response.ContentType = "application/json";
            var result = JsonSerializer.Serialize(new
            {
                status = report.Status.ToString(),
                timestamp = DateTime.UtcNow,
                totalDuration = report.TotalDuration.TotalMilliseconds,
                checks = report.Entries.Select(e => new
                {
                    name = e.Key,
                    status = e.Value.Status.ToString(),
                    description = e.Value.Description,
                    duration = e.Value.Duration.TotalMilliseconds,
                    tags = e.Value.Tags
                })
            }, new JsonSerializerOptions
            {
                WriteIndented = true
            });
            await context.Response.WriteAsync(result);
        }
    });

    // Simple health check endpoint (ready/alive probe)
    app.MapHealthChecks("/health/ready", new HealthCheckOptions
    {
        Predicate = _ => true,
        ResponseWriter = async (context, report) =>
        {
            context.Response.ContentType = "text/plain";
            await context.Response.WriteAsync(report.Status.ToString());
        }
    });

    app.MapControllers();

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

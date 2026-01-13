using App.Abstractions;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Moq;

namespace AuthSamples.IntegrationTests.Fixtures;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((context, config) =>
        {
            // Add test configuration
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:AuthDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;",
                ["CognitoSettings:UserPoolId"] = "test-user-pool-id",
                ["CognitoSettings:ClientId"] = "test-client-id",
                ["CognitoSettings:ClientSecret"] = "test-client-secret",
                ["CognitoSettings:Region"] = "us-east-1"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove the app's AuthDbContext registration
            var dbContextDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AuthDbContext>));

            if (dbContextDescriptor != null)
            {
                services.Remove(dbContextDescriptor);
            }

            // Remove the real DbContext service
            var dbContextServiceDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(AuthDbContext));

            if (dbContextServiceDescriptor != null)
            {
                services.Remove(dbContextServiceDescriptor);
            }

            // Add AuthDbContext using an in-memory database for testing
            services.AddDbContext<AuthDbContext>(options =>
            {
                options.UseInMemoryDatabase($"InMemoryDbForTesting_{Guid.NewGuid()}");
            });

            // Remove the real Cognito service
            var cognitoServiceDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(ICognitoService));

            if (cognitoServiceDescriptor != null)
            {
                services.Remove(cognitoServiceDescriptor);
            }

            // Add mock Cognito service
            var mockCognitoService = new Mock<ICognitoService>();
            mockCognitoService
                .Setup(x => x.SignUpAsync(
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>()))
                .ReturnsAsync(new CognitoSignUpResult
                {
                    Success = true,
                    Subject = Guid.NewGuid().ToString(),
                    UserConfirmed = false
                });

            mockCognitoService
                .Setup(x => x.AuthenticateAsync(It.IsAny<string>(), It.IsAny<string>()))
                .ReturnsAsync(new CognitoAuthResult
                {
                    Success = true,
                    AccessToken = "test-access-token",
                    IdToken = "test-id-token",
                    RefreshToken = "test-refresh-token",
                    ExpiresIn = 3600
                });

            services.AddSingleton(mockCognitoService.Object);

            // Remove IAppMigrator to skip migrations in tests
            services.RemoveAll<IAppMigrator>();

            // Clear existing health checks and add mock ones
            var healthCheckDescriptors = services.Where(d =>
                d.ServiceType == typeof(HealthCheckService) ||
                d.ServiceType.FullName?.Contains("HealthCheck") == true).ToList();

            foreach (var descriptor in healthCheckDescriptors)
            {
                services.Remove(descriptor);
            }

            // Re-add health checks with a simple mock
            services.AddHealthChecks()
                .AddCheck("Test Health Check", () => HealthCheckResult.Healthy("Test is healthy"));

            // Build the service provider
            var sp = services.BuildServiceProvider();

            // Create a scope to obtain a reference to the database context
            using var scope = sp.CreateScope();
            var scopedServices = scope.ServiceProvider;
            var db = scopedServices.GetRequiredService<AuthDbContext>();

            // Ensure the database is created
            db.Database.EnsureCreated();

            // Seed test data
            SeedTestData(db);
        });

        builder.UseEnvironment("Testing");
    }

    private static void SeedTestData(AuthDbContext db)
    {
        // Seed default user role
        if (!db.UserRoles.Any())
        {
            var userRole = AuthSamples.Modules.Auth.Domain.Entities.UserRole.Create("User", "Standard user role");
            var adminRole = AuthSamples.Modules.Auth.Domain.Entities.UserRole.Create("Admin", "Administrator role");
            var ssoRole = AuthSamples.Modules.Auth.Domain.Entities.UserRole.Create("SsoUser", "SSO user role");

            db.UserRoles.AddRange(userRole, adminRole, ssoRole);
            db.SaveChanges();
        }

        // Seed default IdP (IFX Cognito)
        if (!db.Idps.Any())
        {
            var idp = AuthSamples.Modules.Auth.Domain.Entities.Idp.Create(
                name: "IFX Cognito",
                issuer: "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P",
                authority: "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P",
                description: "IFX AWS Cognito Identity Provider",
                loginUrl: "",
                enabled: true,
                autoProvisionEnabled: true);

            db.Idps.Add(idp);
            db.SaveChanges();
        }
    }
}

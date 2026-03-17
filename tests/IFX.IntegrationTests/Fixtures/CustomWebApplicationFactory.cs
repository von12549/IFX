using App.Abstractions;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Platform.BackgroundJobs.Abstractions;
using IFX.Platform.Notifications.Abstractions;
using IFX.Platform.Notifications.Abstractions.Models;
using Hangfire;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Moq;

namespace IFX.IntegrationTests.Fixtures;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((context, config) =>
        {
            // Add test configuration - must override all required settings
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:AuthDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["ConnectionStrings:BackgroundJobsDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["CognitoSettings:UserPoolId"] = "test-user-pool-id",
                ["CognitoSettings:ClientId"] = "test-client-id",
                ["CognitoSettings:ClientSecret"] = "test-client-secret",
                ["CognitoSettings:Region"] = "us-east-1",
                // Identity provider selection
                ["Authentication:Provider"] = "Cognito",
                // CognitoOidcSettings for OAuth
                ["CognitoOidcSettings:Domain"] = "test-domain.auth.us-east-1.amazoncognito.com",
                ["CognitoOidcSettings:ClientId"] = "test-client-id",
                ["CognitoOidcSettings:ClientSecret"] = "test-client-secret",
                ["CognitoOidcSettings:CallbackUrl"] = "http://localhost:5010/api/v1/auth/oauth/callback",
                ["CognitoOidcSettings:LogoutCallbackUrl"] = "http://localhost:5010/api/v1/auth/oauth/logout",
                ["CognitoOidcSettings:FrontendCallbackUrl"] = "http://localhost:3000/callback",
                // Disable background jobs for testing
                ["BackgroundJobs:Enabled"] = "false",
                ["BackgroundJobs:EnableDashboard"] = "false"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove the app's IfxDbContext registration
            var dbContextDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<IfxDbContext>));

            if (dbContextDescriptor != null)
            {
                services.Remove(dbContextDescriptor);
            }

            // Remove the real DbContext service
            var dbContextServiceDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IfxDbContext));

            if (dbContextServiceDescriptor != null)
            {
                services.Remove(dbContextServiceDescriptor);
            }

            // Add IfxDbContext using an in-memory database for testing
            services.AddDbContext<IfxDbContext>(options =>
            {
                options.UseInMemoryDatabase($"InMemoryDbForTesting_{Guid.NewGuid()}");
            });

            // Remove the real identity provider service
            var identityProviderDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IIdentityProvider));

            if (identityProviderDescriptor != null)
            {
                services.Remove(identityProviderDescriptor);
            }

            // Add mock identity provider
            var mockIdentityProvider = new Mock<IIdentityProvider>();
            mockIdentityProvider
                .Setup(x => x.SignUpAsync(
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<string>()))
                .ReturnsAsync(new ProviderSignUpResult
                {
                    Success = true,
                    Subject = Guid.NewGuid().ToString(),
                    UserConfirmed = false
                });

            mockIdentityProvider
                .Setup(x => x.AuthenticateAsync(It.IsAny<string>(), It.IsAny<string>()))
                .ReturnsAsync(new AuthTokenResult
                {
                    Success = true,
                    AccessToken = "test-access-token",
                    IdToken = "test-id-token",
                    RefreshToken = "test-refresh-token",
                    ExpiresIn = 3600
                });

            services.AddSingleton(mockIdentityProvider.Object);

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

            // Remove Hangfire services (they require SQL Server)
            RemoveHangfireServices(services);

            // Add mock background job service
            var mockBackgroundJobService = new Mock<IBackgroundJobService>();
            mockBackgroundJobService.Setup(x => x.Enqueue(It.IsAny<System.Linq.Expressions.Expression<Action<It.IsAnyType>>>()))
                .Returns("test-job-id");
            services.AddSingleton(mockBackgroundJobService.Object);

            // Remove SendGrid services and add mock email service
            services.RemoveAll<IEmailService>();
            var mockEmailService = new Mock<IEmailService>();
            mockEmailService.Setup(x => x.SendEmailAsync(It.IsAny<EmailMessage>(), It.IsAny<CancellationToken>()))
                .ReturnsAsync(EmailResult.Success("test-message-id"));
            mockEmailService.Setup(x => x.SendTemplatedEmailAsync(It.IsAny<TemplatedEmailMessage>(), It.IsAny<CancellationToken>()))
                .ReturnsAsync(EmailResult.Success("test-message-id"));
            services.AddSingleton(mockEmailService.Object);

            // Build the service provider
            var sp = services.BuildServiceProvider();

            // Create a scope to obtain a reference to the database context
            using var scope = sp.CreateScope();
            var scopedServices = scope.ServiceProvider;
            var db = scopedServices.GetRequiredService<IfxDbContext>();

            // Ensure the database is created
            db.Database.EnsureCreated();

            // Seed test data
            SeedTestData(db);
        });

        builder.UseEnvironment("Testing");
    }

    private static void SeedTestData(IfxDbContext db)
    {
        // Seed default user role
        if (!db.UserRoles.Any())
        {
            var userRole = IFX.Modules.Auth.Domain.Authorization.UserRole.Create("User", "Standard user role");
            var adminRole = IFX.Modules.Auth.Domain.Authorization.UserRole.Create("Admin", "Administrator role");
            var ssoRole = IFX.Modules.Auth.Domain.Authorization.UserRole.Create("SsoUser", "SSO user role");

            db.UserRoles.AddRange(userRole, adminRole, ssoRole);
            db.SaveChanges();
        }

        // Seed default IdP (IFX Cognito)
        if (!db.Idps.Any())
        {
            var idp = IFX.Modules.Auth.Domain.Identity.Idp.Create(
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

    private static void RemoveHangfireServices(IServiceCollection services)
    {
        // Remove Hangfire-related services
        var hangfireDescriptors = services.Where(d =>
            d.ServiceType.FullName?.Contains("Hangfire") == true ||
            d.ImplementationType?.FullName?.Contains("Hangfire") == true ||
            d.ServiceType == typeof(IBackgroundJobClient) ||
            d.ServiceType == typeof(IRecurringJobManager) ||
            d.ServiceType == typeof(IBackgroundJobService) ||
            d.ServiceType == typeof(JobStorage) ||
            d.ServiceType.FullName?.Contains("BackgroundJob") == true).ToList();

        foreach (var descriptor in hangfireDescriptors)
        {
            services.Remove(descriptor);
        }

        // Remove hosted services that might be Hangfire-related
        var hostedServiceDescriptors = services.Where(d =>
            d.ServiceType == typeof(Microsoft.Extensions.Hosting.IHostedService) &&
            d.ImplementationType?.FullName?.Contains("Hangfire") == true).ToList();

        foreach (var descriptor in hostedServiceDescriptors)
        {
            services.Remove(descriptor);
        }
    }
}

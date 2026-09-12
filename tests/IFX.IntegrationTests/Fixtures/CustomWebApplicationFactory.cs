using IFX.BuildingBlocks.Composition;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Infrastructure.Access;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Ports.Authorization;

using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Platform.BackgroundJobs.Contracts;
using IFX.Platform.Notifications.Contracts;
using IFX.Platform.Notifications.Contracts.Models;
using Hangfire;
using Microsoft.AspNetCore.Authentication;
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
                ["Runtime:Role"] = "api",
                ["Runtime:DependencyPollSeconds"] = "1",
                ["Runtime:DependencyTimeoutSeconds"] = "1",
                ["ConnectionStrings:AuthDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["ConnectionStrings:CrmDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["ConnectionStrings:RegistryDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["ConnectionStrings:HoldingsDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["ConnectionStrings:TransactionDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["ConnectionStrings:BackgroundJobsDatabase"] = "Server=localhost;Database=TestDb;Integrated Security=true;TrustServerCertificate=true;",
                ["CognitoSettings:UserPoolId"] = "test-user-pool-id",
                ["CognitoSettings:ClientId"] = "test-client-id",
                ["CognitoSettings:ClientSecret"] = "test-client-secret",
                ["CognitoSettings:Region"] = "us-east-1",
                // Identity provider selection
                ["Authentication:Provider"] = "Cognito",
                ["Opa:Enabled"] = "false",
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
            services.RemoveAll<IExternalAccountService>();
            services.RemoveAll<ICredentialAuthenticationService>();
            services.RemoveAll<ITokenLifecycleService>();

            // Add mock identity provider
            var mockIdentityProvider = new Mock<IExternalAccountService>();
            var mockCredentials = new Mock<ICredentialAuthenticationService>();
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

            mockCredentials
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
            services.AddSingleton(mockCredentials.Object);
            services.AddSingleton(Mock.Of<ITokenLifecycleService>());

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

        builder.ConfigureServices(services =>
        {
            // Routing tests inject test identities; production VerifiedIdentityFacts has dedicated storage tests.
            services.RemoveAll<IExecutionIdentityFacts>();
            services.AddScoped<RoutingTestIdentityFacts>();
            services.AddScoped<IExecutionIdentityFacts>(sp => sp.GetRequiredService<RoutingTestIdentityFacts>());
            services.RemoveAll<ICurrentUser>();
            services.AddScoped<ICurrentUser, RoutingTestCurrentUser>();
            // Remove UserPermissionClaimsTransformation to prevent DB calls during test auth
            services.RemoveAll<IClaimsTransformation>();
            services.RemoveAll<IResourceAuthorizationService>();
            services.AddScoped<IResourceAuthorizationService, AllowAllResourceAuthorizationService>();
            services.RemoveAll<IFX.Modules.IAM.Contracts.V1.Authorization.IResourceAuthorizationContract>();
            services.AddScoped<IFX.Modules.IAM.Contracts.V1.Authorization.IResourceAuthorizationContract, AllowAllResourceAuthorizationService>();

            // Override the default auth scheme with the test handler
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
        });

        builder.UseEnvironment("Testing");
    }

    /// <summary>
    /// Creates an authenticated HttpClient. Requests will be treated as authenticated
    /// with the specified permission claims. No permissions = authenticated but no access.
    /// </summary>
    public HttpClient CreateAuthenticatedClient(params string[] permissions)
    {
        var client = CreateClient();
        // Use a non-empty sentinel when no permissions are specified
        // because HttpClient drops empty-string header values.
        var headerValue = permissions.Length > 0 ? string.Join(",", permissions) : "-";
        client.DefaultRequestHeaders.Add(TestAuthHandler.PermissionsHeader, headerValue);
        return client;
    }

    private static void SeedTestData(IfxDbContext db)
    {
        // Seed default roles
        if (!db.Roles.Any())
        {
            var defaultTenantId = Guid.NewGuid();
            var userRole = IFX.Modules.IAM.Domain.Access.Role.Create("User", "Standard user role", defaultTenantId);
            var adminRole = IFX.Modules.IAM.Domain.Access.Role.Create("Admin", "Administrator role", defaultTenantId);
            var ssoRole = IFX.Modules.IAM.Domain.Access.Role.Create("SsoUser", "SSO user role", defaultTenantId);
            var pendingRole = IFX.Modules.IAM.Domain.Access.Role.Create("PendingUser", "Pending user awaiting approval", defaultTenantId);

            db.Roles.AddRange(userRole, adminRole, ssoRole, pendingRole);
            db.SaveChanges();
        }

        // Seed default IdP (IFX Cognito)
        if (!db.Idps.Any())
        {
            var idp = IFX.Modules.IAM.Domain.Identity.Idp.Create(
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

    private sealed class RoutingTestCurrentUser(RoutingTestIdentityFacts facts, ExecutionTenantSelection selection) : ICurrentUser
    {
        public bool IsAuthenticated => facts.IsAuthenticated;
        public Guid UserId => facts.UserId;
        public Guid? TenantId => selection.ResolveTenantId();
        public IReadOnlyCollection<string> Departments => facts.Departments;
        public IReadOnlyCollection<string> Roles => facts.Roles;
        public IReadOnlyCollection<string> Permissions => facts.Permissions;
        public IReadOnlyList<string> GlobalRoles => [];
        public bool IsGlobalAdmin => false;
        public bool MfaEnabled => facts.MfaEnabled;
    }
    private sealed class AllowAllResourceAuthorizationService : IResourceAuthorizationService, IFX.Modules.IAM.Contracts.V1.Authorization.IResourceAuthorizationContract
    {
        public Task<IFX.Modules.IAM.Contracts.V1.Authorization.ResourceAuthorizationResponse> AuthorizeAsync(IFX.Modules.IAM.Contracts.V1.Authorization.ResourceAuthorizationRequest request, IFX.Platform.Context.Contracts.Context.ContractRequestContext context, CancellationToken ct = default) => Task.FromResult(new IFX.Modules.IAM.Contracts.V1.Authorization.ResourceAuthorizationResponse(true, "test_only"));

        public Task AuthorizeWithResolvedPolicyAsync<TResource>(
            string resourceType,
            string action,
            TResource resourceAttributes,
            IDictionary<string, object>? parameters = null,
            CancellationToken ct = default)
            where TResource : ResourceAttributes => Task.CompletedTask;
    }

    private static void RemoveHangfireServices(IServiceCollection services)
    {
        // Remove Hangfire-related services (but not BackgroundJobsSettings which is still needed)
        var hangfireDescriptors = services.Where(d =>
            d.ServiceType.FullName?.Contains("Hangfire") == true ||
            d.ImplementationType?.FullName?.Contains("Hangfire") == true ||
            d.ServiceType == typeof(IBackgroundJobClient) ||
            d.ServiceType == typeof(IRecurringJobManager) ||
            d.ServiceType == typeof(IBackgroundJobService) ||
            d.ServiceType == typeof(JobStorage)).ToList();

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

using Hangfire;
using Hangfire.Common;
using Hangfire.Storage;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Composition;
using IFX.Platform.BackgroundJobs.Composition;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Runtime;

[CollectionDefinition("Job type compatibility", DisableParallelization = true)]
public sealed class JobTypeCompatibilityCollection;

[Collection("Job type compatibility")]
public sealed class IamJobCompatibilityTests
{
    [Theory]
    [InlineData("")]
    [InlineData(", Version=1.0.0.0, Culture=neutral, PublicKeyToken=null")]
    public async Task Persisted_auth_cleanup_job_deserializes_to_iam_and_executes_with_preserved_arguments(string qualification)
    {
        var services = new ServiceCollection();
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:AuthDatabase"] = "Server=unused;Database=unused;Integrated Security=true"
        }).Build();
        new IamModuleInstaller().InstallServices(services, configuration);
        using var provider = services.BuildServiceProvider();
        var resolver = new BackgroundJobTypeResolver(provider.GetServices<BackgroundJobTypeAlias>());
        var originalResolver = TypeHelper.CurrentTypeResolver;
        var originalSerializer = TypeHelper.CurrentTypeSerializer;
        try
        {
            GlobalConfiguration.Configuration.UseTypeResolver(resolver.Resolve).UseSimpleAssemblyNameTypeSerializer();
            var current = InvocationData.SerializeJob(Job.FromExpression<IEmailVerificationCleanupService>(service => service.CleanupExpiredTokensAsync(CancellationToken.None)));
            var legacy = new InvocationData(
                "IFX.Modules.Auth.Application.Identity.Interfaces.IEmailVerificationCleanupService, IFX.Modules.Auth.Application" + qualification,
                current.Method, current.ParameterTypes, current.Arguments);

            var restored = legacy.DeserializeJob();

            Assert.Equal(typeof(IEmailVerificationCleanupService), restored.Type);
            Assert.Equal(nameof(IEmailVerificationCleanupService.CleanupExpiredTokensAsync), restored.Method.Name);
            Assert.Single(restored.Args);
            Assert.Equal(CancellationToken.None, restored.Args[0]);
            var service = new CleanupProbe();
            await (Task)restored.Method.Invoke(service, restored.Args.ToArray())!;
            Assert.Equal(1, service.Calls);
            Assert.Contains("IFX.Modules.IAM.Application", InvocationData.SerializeJob(restored).Type);
            Assert.ThrowsAny<Exception>(() => resolver.Resolve("Unknown.Interface, IFX.Modules.Auth.UnknownAssembly"));
        }
        finally
        {
            GlobalConfiguration.Configuration.UseTypeResolver(originalResolver).UseTypeSerializer(originalSerializer);
        }
    }

    private sealed class CleanupProbe : IEmailVerificationCleanupService
    {
        public int Calls { get; private set; }
        public Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default)
        {
            Assert.Equal(CancellationToken.None, cancellationToken);
            Calls++;
            return Task.CompletedTask;
        }
    }
}

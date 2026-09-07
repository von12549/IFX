using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace IFX.ApiHost.Runtime;

public static class RuntimeProfileResolver
{
    public static RuntimeProfile Resolve(IConfiguration configuration, IHostEnvironment environment)
    {
        var configuredRole = configuration["Runtime:Role"];
        var roleName = string.IsNullOrWhiteSpace(configuredRole)
            ? environment.IsProduction() ? "api" : "all"
            : configuredRole.Trim().ToLowerInvariant();

        var role = roleName switch
        {
            "api" => RuntimeRole.Api,
            "worker" => RuntimeRole.Worker,
            "all" => RuntimeRole.All,
            _ => throw new RuntimeConfigurationException("G04-RUNTIME-UNKNOWN-ROLE", $"Unknown Runtime:Role '{configuredRole}'. Expected api, worker, or all.")
        };

        if (role == RuntimeRole.All && environment.IsProduction() && !configuration.GetValue<bool>("Runtime:AllowAllInProduction"))
        {
            throw new RuntimeConfigurationException("G04-RUNTIME-PRODUCTION-ALL-DISALLOWED", "Runtime:Role=all is disabled in production unless Runtime:AllowAllInProduction=true is explicitly approved.");
        }

        var defaults = role switch
        {
            RuntimeRole.Api => new RuntimeCapabilities(true, true, false, false, false, false),
            RuntimeRole.Worker => new RuntimeCapabilities(false, true, true, false, false, false),
            RuntimeRole.All => new RuntimeCapabilities(true, true, true, false, false, false),
            _ => throw new ArgumentOutOfRangeException(nameof(role))
        };

        var capabilities = new RuntimeCapabilities(
            Api: ReadFlag(configuration, "Runtime:Capabilities:Api", defaults.Api),
            HangfireClient: ReadFlag(configuration, "Runtime:Capabilities:HangfireClient", defaults.HangfireClient),
            HangfireServer: ReadFlag(configuration, "Runtime:Capabilities:HangfireServer", defaults.HangfireServer),
            Dispatcher: ReadFlag(configuration, "Runtime:Capabilities:Dispatcher", defaults.Dispatcher),
            Consumers: ReadFlag(configuration, "Runtime:Capabilities:Consumers", defaults.Consumers),
            RecurringScheduler: ReadFlag(configuration, "Runtime:Capabilities:RecurringScheduler", defaults.RecurringScheduler));

        Validate(role, capabilities);
        return new RuntimeProfile(role, capabilities);
    }

    private static bool ReadFlag(IConfiguration configuration, string key, bool fallback) =>
        configuration.GetValue<bool?>(key) ?? fallback;

    private static void Validate(RuntimeRole role, RuntimeCapabilities capabilities)
    {
        if (role == RuntimeRole.Api && (!capabilities.Api || capabilities.HasWorkerExecution))
        {
            throw new RuntimeConfigurationException("G04-RUNTIME-API-CAPABILITY-MISMATCH", "The api role must expose API capability and cannot execute Hangfire Server, Dispatcher, Consumers, or Recurring Scheduler.");
        }

        if (role == RuntimeRole.Worker && (capabilities.Api || !capabilities.HasWorkerExecution))
        {
            throw new RuntimeConfigurationException("G04-RUNTIME-WORKER-CAPABILITY-MISMATCH", "The worker role cannot expose business API endpoints and must enable at least one worker execution capability.");
        }

        if (role == RuntimeRole.All && (!capabilities.Api || !capabilities.HasWorkerExecution))
        {
            throw new RuntimeConfigurationException("G04-RUNTIME-ALL-CAPABILITY-MISMATCH", "The all role must combine API and at least one worker execution capability.");
        }

        if ((capabilities.HangfireServer || capabilities.RecurringScheduler) && !capabilities.HangfireClient)
        {
            throw new RuntimeConfigurationException("G04-RUNTIME-HANGFIRE-CLIENT-REQUIRED", "Hangfire Server and Recurring Scheduler require Hangfire Client capability.");
        }
    }
}

public sealed class RuntimeConfigurationException(string reasonCode, string message) : InvalidOperationException(message)
{
    public string ReasonCode { get; } = reasonCode;
}

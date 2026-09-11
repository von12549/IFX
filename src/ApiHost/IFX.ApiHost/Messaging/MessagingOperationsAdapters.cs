using IFX.BuildingBlocks.Security.Authorization;
using IFX.Platform.Messaging.Composition;

namespace IFX.ApiHost.Messaging;

public sealed class MessagingOperationsAuthorizer(IPermissionChecker permissionChecker) : IMessagingOperationsAuthorizer
{
    public Task<bool> IsAuthorizedAsync(string actorId, string action, string moduleId, CancellationToken cancellationToken) =>
        permissionChecker.HasPermissionAsync(action switch
        {
            "messaging.diagnostics.read" => "Messaging.Diagnostics.Read",
            "messaging.replay.preview" => "Messaging.Replay.Preview",
            "messaging.replay.execute" => "Messaging.Replay.Execute",
            _ => "Messaging.Deny"
        }, cancellationToken);
}

public sealed class ConfiguredMessagingReplayGuard(IConfiguration configuration) : IMessagingReplayGuard
{
    public Task<string?> ValidateAsync(
        MessagingOutboxDiagnostic message,
        string targetHandlerVersion,
        CancellationToken cancellationToken)
    {
        var supported = configuration[$"Messaging:Replay:SupportedHandlers:{message.EventType}"];
        var rejection = message.SchemaVersion <= 0 || !string.Equals(supported, targetHandlerVersion, StringComparison.Ordinal)
            ? "HANDLER-VERSION-INCOMPATIBLE"
            : null;
        return Task.FromResult(rejection);
    }
}

public sealed class LoggingMessagingOperationsAuditSink(ILogger<LoggingMessagingOperationsAuditSink> logger) : IMessagingOperationsAuditSink
{
    public Task WriteAsync(MessagingOperationsAuditRecord record, CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Messaging operation audit {RequestId} {Action} {ModuleId} events {EventIds} actor {ActorId} reason {Reason} dry-run {DryRun} authorized {Authorized} handler {TargetHandlerVersion}",
            record.RequestId, record.Action, record.ModuleId,
            string.Join(',', record.EventIds.Select(item => item.ToString("D"))), record.ActorId, record.Reason,
            record.DryRun, record.Authorized, record.TargetHandlerVersion);
        return Task.CompletedTask;
    }
}

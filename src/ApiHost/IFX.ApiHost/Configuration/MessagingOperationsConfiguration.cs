using IFX.ApiHost.Messaging;
using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Messaging.Composition;

namespace IFX.ApiHost.Configuration;

public static class MessagingOperationsConfiguration
{
    public static IServiceCollection AddMessagingOperationsControlPlane(this IServiceCollection services) =>
        services.AddMessagingOperations<MessagingOperationsAuthorizer, ConfiguredMessagingReplayGuard, LoggingMessagingOperationsAuditSink>();

    public static IEndpointRouteBuilder MapMessagingOperationsEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/management/messaging/diagnostics", async (
            Guid? eventId,
            DateTimeOffset? from,
            DateTimeOffset? to,
            string? eventType,
            Guid? tenantId,
            int? limit,
            IMessagingOperations operations,
            IExecutionContextAccessor execution,
            CancellationToken cancellationToken) =>
            Results.Ok(await operations.QueryAsync(
                new MessagingDiagnosticQuery(eventId, from, to, eventType, tenantId, limit ?? 100),
                execution.Current.Actor.Id,
                cancellationToken)))
            .WithMetadata(ExecutionScopeRequirement.Platform)
            .RequireAuthorization("Messaging.Diagnostics.Read");

        endpoints.MapPost("/management/messaging/replay/preview", async (
            MessagingReplayApiRequest request,
            IMessagingOperations operations,
            IExecutionContextAccessor execution,
            CancellationToken cancellationToken) =>
            Results.Ok(await operations.ReplayAsync(request.ToOperation(execution.Current.Actor.Id, dryRun: true), cancellationToken)))
            .WithMetadata(ExecutionScopeRequirement.Platform)
            .RequireAuthorization("Messaging.Replay.Preview");

        endpoints.MapPost("/management/messaging/replay", async (
            MessagingReplayApiRequest request,
            IMessagingOperations operations,
            IExecutionContextAccessor execution,
            CancellationToken cancellationToken) =>
            Results.Ok(await operations.ReplayAsync(request.ToOperation(execution.Current.Actor.Id, dryRun: false), cancellationToken)))
            .WithMetadata(ExecutionScopeRequirement.Platform)
            .RequireAuthorization("Messaging.Replay.Execute");

        return endpoints;
    }

    public sealed record MessagingReplayApiRequest(
        Guid RequestId,
        string ModuleId,
        IReadOnlyCollection<Guid> EventIds,
        string Reason,
        string TargetHandlerVersion)
    {
        internal MessagingReplayRequest ToOperation(string actorId, bool dryRun) =>
            new(RequestId, ModuleId, EventIds, actorId, Reason, TargetHandlerVersion, dryRun);
    }
}

using System.Text.Json;
using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class ContractContextConformanceTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");
    private static readonly Guid CorrelationId = Guid.Parse("60a0e08c-2dd9-4f76-af07-e624f5adbe53");
    private static readonly Guid OperationId = Guid.Parse("1571d680-91cf-4f7c-853d-49cb816376e7");

    [Fact]
    public async Task EveryInvocation_GeneratesRequestIdAndPreservesBusinessChain()
    {
        var observed = new List<ContractRequestContext>();
        var port = CreatePort(new DirectContractCarrier(CreateProvider(context => observed.Add(context))));

        await port.CheckAsync(TenantId, CancellationToken.None);
        await port.CheckAsync(TenantId, CancellationToken.None);

        observed.Should().HaveCount(2);
        observed.Select(context => context.RequestId).Should().OnlyHaveUniqueItems();
        observed.Should().OnlyContain(context =>
            context.CorrelationId == CorrelationId && context.CausationId == OperationId);
    }

    [Fact]
    public async Task Provider_RebuildsTrustedChildExecutionContext()
    {
        ExecutionContextSnapshot? child = null;
        var port = CreatePort(new DirectContractCarrier(CreateProvider((_, context) => child = context)));

        var result = await port.CheckAsync(TenantId, CancellationToken.None);

        result.Code.Should().Be(ContractResultCodes.Success);
        child.Should().NotBeNull();
        child!.CorrelationId.Value.Should().Be(CorrelationId);
        child.OperationId.Value.Should().NotBe(Guid.Empty).And.NotBe(OperationId);
        child.CausationId!.Value.Value.Should().Be(OperationId);
        child.TenantId.Should().Be(TenantId);
    }

    [Fact]
    public async Task Provider_ConsumerAllowlistRunsBeforeOtherContextChecks()
    {
        var denied = new ContractRequestContext(
            Guid.NewGuid(), CorrelationId, OperationId,
            ContractRequestContext.TenantScope, TenantId,
            "user", "actor-1", "ifx", "unknown-consumer", 1,
            ContractRequestContext.SynthesizedProvenance);
        var provider = CreateProvider();

        var result = await provider.InvokeAsync(denied, Guid.NewGuid(), CancellationToken.None);

        result.Code.Should().Be(ContractResultCodes.ConsumerDenied);
        provider.ValidationTrace.Should().Equal("consumerAllowlist");
    }

    [Fact]
    public async Task Provider_RejectsUntrustedProvenanceWithStableContextCode()
    {
        var context = CreateRequestContext(provenance: ContractRequestContext.SynthesizedProvenance);
        var provider = CreateProvider();

        var result = await provider.InvokeAsync(context, TenantId, CancellationToken.None);

        result.Code.Should().Be(ContractResultCodes.ContextInvalid);
        provider.ValidationTrace.Should().Equal("consumerAllowlist", "version", "scope", "actorSource");
    }

    [Fact]
    public async Task Provider_RejectsTenantResourceMismatchWithStableCode()
    {
        var provider = CreateProvider();

        var result = await provider.InvokeAsync(CreateRequestContext(), Guid.NewGuid(), CancellationToken.None);

        result.Code.Should().Be(ContractResultCodes.TenantMismatch);
        provider.ValidationTrace.Should().Equal(
            "consumerAllowlist", "version", "scope", "actorSource", "tenantResource");
    }

    [Theory]
    [InlineData("timeout", ContractResultCodes.Timeout)]
    [InlineData("cancel", ContractResultCodes.Cancelled)]
    [InlineData("unavailable", ContractResultCodes.Unavailable)]
    public async Task ConsumerAdapter_MapsCarrierFailuresToStableCodes(string fault, string expected)
    {
        using var cancellation = new CancellationTokenSource();
        if (fault == "cancel")
        {
            cancellation.Cancel();
        }

        var port = CreatePort(new FaultingContractCarrier(fault));

        var result = await port.CheckAsync(TenantId, cancellation.Token);

        result.Code.Should().Be(expected);
    }

    [Fact]
    public async Task CarrierSubstitution_DoesNotChangeConsumerApplicationPort()
    {
        var direct = CreatePort(new DirectContractCarrier(CreateProvider()));
        var serialized = CreatePort(new JsonRoundTripContractCarrier(CreateProvider()));

        var directResult = await direct.CheckAsync(TenantId, CancellationToken.None);
        var serializedResult = await serialized.CheckAsync(TenantId, CancellationToken.None);

        directResult.Should().Be(serializedResult);
        directResult.Should().Be(new ContractDecision(ContractResultCodes.Success, true));
    }

    [Fact]
    public async Task JsonCarrier_UnknownAuthorizationClaimsDoNotInfluenceProvider()
    {
        var carrier = new JsonRoundTripContractCarrier(
            CreateProvider(),
            json => json.TrimEnd('}') + ",\"authorizationGranted\":true,\"roles\":[\"global-admin\"]}");
        var port = CreatePort(carrier);

        var result = await port.CheckAsync(TenantId, CancellationToken.None);

        result.Code.Should().Be(ContractResultCodes.Success);
        carrier.LastWireJson.Should().Contain("authorizationGranted");
    }

    [Fact]
    public void ContractRequestContext_HasNoCallerAssertedSecurityPayload()
    {
        var propertyNames = typeof(ContractRequestContext).GetProperties()
            .Select(property => property.Name)
            .ToArray();

        propertyNames.Should().NotContain(name =>
            name.Contains("token", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("principal", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("role", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("authorization", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("permission", StringComparison.OrdinalIgnoreCase));
    }

    private static AccountCompliancePortAdapter CreatePort(IContractCarrier carrier) => new(
        CreateExecutionContext(), carrier, "ifx", "transaction", 1);

    private static ConformanceProviderAdapter CreateProvider(Action<ContractRequestContext>? observe = null) =>
        new(new HashSet<string> { "ifx.transaction.v1" }, observe is null ? null : (context, _) => observe(context));

    private static ConformanceProviderAdapter CreateProvider(Action<ContractRequestContext, ExecutionContextSnapshot> observe) =>
        new(new HashSet<string> { "ifx.transaction.v1" }, observe);

    private static ExecutionContextSnapshot CreateExecutionContext() => new(
        new CorrelationId(CorrelationId),
        new OperationId(OperationId),
        null,
        ExecutionScope.ForTenant(new TenantScope(TenantId)),
        new ActorReference(ActorKind.User, "actor-1"),
        new SourceReference("ifx", "api-host", 1));

    private static ContractRequestContext CreateRequestContext(
        string provenance = ContractRequestContext.TrustedProvenance) => new(
        Guid.NewGuid(), CorrelationId, OperationId,
        ContractRequestContext.TenantScope, TenantId,
        "user", "actor-1", "ifx", "transaction", 1, provenance);
}

internal static class ContractResultCodes
{
    public const string Success = "success";
    public const string ContextInvalid = "contract_context_invalid";
    public const string ConsumerDenied = "contract_consumer_denied";
    public const string TenantMismatch = "contract_tenant_mismatch";
    public const string Timeout = "contract_timeout";
    public const string Cancelled = "contract_cancelled";
    public const string Unavailable = "contract_unavailable";
}

internal sealed record ContractDecision(string Code, bool IsCompliant);

internal interface IAccountCompliancePort
{
    Task<ContractDecision> CheckAsync(Guid resourceTenantId, CancellationToken cancellationToken);
}

internal sealed class AccountCompliancePortAdapter(
    ExecutionContextSnapshot executionContext,
    IContractCarrier carrier,
    string sourceSystem,
    string sourceComponent,
    int sourceVersion) : IAccountCompliancePort
{
    public async Task<ContractDecision> CheckAsync(Guid resourceTenantId, CancellationToken cancellationToken)
    {
        var context = new ContractRequestContext(
            Guid.NewGuid(),
            executionContext.CorrelationId.Value,
            executionContext.OperationId.Value,
            executionContext.Scope.IsTenant ? ContractRequestContext.TenantScope : ContractRequestContext.PlatformScope,
            executionContext.TenantId,
            executionContext.Actor.Kind.ToString().ToLowerInvariant(),
            executionContext.Actor.Id,
            sourceSystem,
            sourceComponent,
            sourceVersion,
            executionContext.Provenance == ContextProvenance.Trusted
                ? ContractRequestContext.TrustedProvenance
                : ContractRequestContext.SynthesizedProvenance);

        try
        {
            return await carrier.InvokeAsync(context, resourceTenantId, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return new ContractDecision(ContractResultCodes.Cancelled, false);
        }
        catch (TimeoutException)
        {
            return new ContractDecision(ContractResultCodes.Timeout, false);
        }
        catch (ContractUnavailableException)
        {
            return new ContractDecision(ContractResultCodes.Unavailable, false);
        }
        catch (ArgumentException)
        {
            return new ContractDecision(ContractResultCodes.ContextInvalid, false);
        }
        catch (JsonException)
        {
            return new ContractDecision(ContractResultCodes.ContextInvalid, false);
        }
    }
}

internal interface IContractCarrier
{
    Task<ContractDecision> InvokeAsync(
        ContractRequestContext context,
        Guid resourceTenantId,
        CancellationToken cancellationToken);
}

internal sealed class DirectContractCarrier(ConformanceProviderAdapter provider) : IContractCarrier
{
    public Task<ContractDecision> InvokeAsync(
        ContractRequestContext context,
        Guid resourceTenantId,
        CancellationToken cancellationToken) =>
        provider.InvokeAsync(context, resourceTenantId, cancellationToken);
}

internal sealed class JsonRoundTripContractCarrier(
    ConformanceProviderAdapter provider,
    Func<string, string>? mutate = null) : IContractCarrier
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    public string? LastWireJson { get; private set; }

    public Task<ContractDecision> InvokeAsync(
        ContractRequestContext context,
        Guid resourceTenantId,
        CancellationToken cancellationToken)
    {
        LastWireJson = mutate?.Invoke(JsonSerializer.Serialize(context, Options)) ??
            JsonSerializer.Serialize(context, Options);
        var restored = JsonSerializer.Deserialize<ContractRequestContext>(LastWireJson, Options) ??
            throw new JsonException("Contract context is required.");
        return provider.InvokeAsync(restored, resourceTenantId, cancellationToken);
    }
}

internal sealed class FaultingContractCarrier(string fault) : IContractCarrier
{
    public Task<ContractDecision> InvokeAsync(
        ContractRequestContext context,
        Guid resourceTenantId,
        CancellationToken cancellationToken) => fault switch
    {
        "timeout" => throw new TimeoutException(),
        "cancel" => Task.FromCanceled<ContractDecision>(cancellationToken),
        "unavailable" => throw new ContractUnavailableException(),
        _ => throw new InvalidOperationException("Unknown conformance fault.")
    };
}

internal sealed class ContractUnavailableException : Exception;

internal sealed class ConformanceProviderAdapter(
    IReadOnlySet<string> allowedConsumers,
    Action<ContractRequestContext, ExecutionContextSnapshot>? observe = null)
{
    public List<string> ValidationTrace { get; } = [];

    public Task<ContractDecision> InvokeAsync(
        ContractRequestContext context,
        Guid resourceTenantId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ValidationTrace.Clear();

        ValidationTrace.Add("consumerAllowlist");
        var consumer = $"{context.SourceSystem}.{context.SourceComponent}.v{context.SourceVersion}";
        if (!allowedConsumers.Contains(consumer))
        {
            return Task.FromResult(new ContractDecision(ContractResultCodes.ConsumerDenied, false));
        }

        ValidationTrace.Add("version");
        if (context.Version != ContractRequestContext.CurrentVersion)
        {
            return Task.FromResult(new ContractDecision(ContractResultCodes.ContextInvalid, false));
        }

        ValidationTrace.Add("scope");
        if (context.Scope is not (ContractRequestContext.TenantScope or ContractRequestContext.PlatformScope))
        {
            return Task.FromResult(new ContractDecision(ContractResultCodes.ContextInvalid, false));
        }

        ValidationTrace.Add("actorSource");
        if (context.Provenance != ContractRequestContext.TrustedProvenance ||
            context.ActorKind is not ("user" or "service" or "system"))
        {
            return Task.FromResult(new ContractDecision(ContractResultCodes.ContextInvalid, false));
        }

        ValidationTrace.Add("tenantResource");
        if (context.Scope != ContractRequestContext.TenantScope || context.TenantId != resourceTenantId)
        {
            return Task.FromResult(new ContractDecision(ContractResultCodes.TenantMismatch, false));
        }

        var child = new ExecutionContextSnapshot(
            new CorrelationId(context.CorrelationId),
            OperationId.New(),
            context.CausationId is { } causationId ? new CausationId(causationId) : null,
            ExecutionScope.ForTenant(new TenantScope(context.TenantId!.Value)),
            new ActorReference(Enum.Parse<ActorKind>(context.ActorKind, true), context.ActorId),
            new SourceReference("ifx", "crm-provider", 1));

        observe?.Invoke(context, child);
        return Task.FromResult(new ContractDecision(ContractResultCodes.Success, true));
    }
}

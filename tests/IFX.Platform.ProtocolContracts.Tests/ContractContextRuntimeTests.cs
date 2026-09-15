using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;
using IFX.Platform.Context.Runtime;
using IFX.Platform.Context.Runtime.Inbound;
using IFX.Platform.Context.Runtime.Outbound;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class ContractContextRuntimeTests
{
    private static readonly Guid TenantId = Guid.Parse("b35a62aa-edfe-47dc-94df-bd70d54fbc74");
    private static readonly ContractComponentIdentity Transaction = new("ifx", "transaction", 1);

    [Theory]
    [InlineData("valid", ContractContextFailure.None)]
    [InlineData("consumer", ContractContextFailure.ConsumerDenied)]
    [InlineData("actor", ContractContextFailure.ContextInvalid)]
    [InlineData("provenance", ContractContextFailure.ContextInvalid)]
    [InlineData("tenant", ContractContextFailure.TenantMismatch)]
    public void Inbound_validator_returns_stable_failure_category(string scenario, ContractContextFailure expected)
    {
        var current = Current();
        var validator = new InboundContractContextValidator(new FixedAccessor(current));
        var policy = new InboundContractPolicy(
            [Transaction],
            ["user", "service", "system"],
            allowTenantScope: true,
            allowPlatformScope: true,
            ContractTenantValidation.RequireTenantResource);
        var context = Context(
            current,
            source: scenario == "consumer" ? "unknown" : "transaction",
            actorId: scenario == "actor" ? "other" : current.Actor.Id,
            provenance: scenario == "provenance" ? ContractRequestContext.SynthesizedProvenance : ContractRequestContext.TrustedProvenance);
        var resourceTenant = scenario == "tenant" ? Guid.NewGuid() : TenantId;

        validator.Validate(context, resourceTenant, policy).Should().Be(expected);
    }

    [Fact]
    public void Provider_factory_preserves_call_chain_and_creates_new_operation()
    {
        var current = Current();
        var context = Context(current);

        var child = new ProviderExecutionContextFactory().Create(
            context,
            new ContractComponentIdentity("ifx", "crm-provider", 1));

        child.CorrelationId.Value.Should().Be(context.CorrelationId);
        child.CausationId!.Value.Value.Should().Be(context.CausationId!.Value);
        child.OperationId.Value.Should().NotBe(current.OperationId.Value);
        child.TenantId.Should().Be(TenantId);
        child.Actor.Id.Should().Be(current.Actor.Id);
        child.Source.Component.Should().Be("crm-provider");
    }

    [Fact]
    public void Outbound_factory_creates_new_request_and_uses_current_operation_as_cause()
    {
        var current = Current();
        var factory = new OutboundContractRequestContextFactory(new FixedAccessor(current));

        var context = factory.CreateTenantCall(TenantId, Transaction);

        context.RequestId.Should().NotBeEmpty();
        context.CorrelationId.Should().Be(current.CorrelationId.Value);
        context.CausationId.Should().Be(current.OperationId.Value);
        context.TenantId.Should().Be(TenantId);
        context.SourceComponent.Should().Be("transaction");
        context.Provenance.Should().Be(ContractRequestContext.TrustedProvenance);
    }

    [Fact]
    public void Trusted_outbound_factory_rejects_untrusted_ambient_context()
    {
        var trusted = Current();
        var current = new ExecutionContextSnapshot(
            trusted.CorrelationId,
            trusted.OperationId,
            trusted.CausationId,
            trusted.Scope,
            trusted.Actor,
            trusted.Source,
            ContextProvenance.Synthesized);
        var factory = new OutboundContractRequestContextFactory(new FixedAccessor(current));

        var action = () => factory.CreateTrusted(Transaction);

        action.Should().Throw<OutboundContractContextException>()
            .Which.Failure.Should().Be(OutboundContractContextFailure.ContextInvalid);
    }

    private static ExecutionContextSnapshot Current() => ExecutionContextSnapshot.ForTenant(
        Guid.NewGuid(), Guid.NewGuid(), null, TenantId,
        "service", "transaction-service", "ifx", "api-host", 1);

    private static ContractRequestContext Context(
        ExecutionContextSnapshot current,
        string source = "transaction",
        string? actorId = null,
        string provenance = ContractRequestContext.TrustedProvenance) => new(
        Guid.NewGuid(),
        current.CorrelationId.Value,
        current.OperationId.Value,
        ContractRequestContext.TenantScope,
        TenantId,
        current.Actor.Kind.ToString().ToLowerInvariant(),
        actorId ?? current.Actor.Id,
        "ifx",
        source,
        1,
        provenance);

    private sealed class FixedAccessor(ExecutionContextSnapshot current) : IExecutionContextAccessor
    {
        public bool HasCurrent => true;

        public ExecutionContextSnapshot Current { get; } = current;
    }
}

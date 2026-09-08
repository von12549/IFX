namespace IFX.BuildingBlocks.Application.Context;

public interface IExecutionIdentityFacts
{
    bool IsAuthenticated { get; }

    Guid UserId { get; }

    Guid? PrimaryTenantId { get; }

    bool IsTenantMember(Guid tenantId);
}

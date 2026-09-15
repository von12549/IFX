using IFX.BuildingBlocks.Security.Authorization;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.IAM.Client.Authorization;

internal static class IamAuthorizationRequestMapper
{
    public static Contract.ResourceAttributes Map(ResourceAttributes source) => new()
    {
        Type = source.Type,
        Id = source.Id,
        TenantId = source.TenantId,
        IsActive = source.IsActive,
        OwnerId = source.OwnerId,
        Departments = source.Departments
    };
}

namespace IFX.BuildingBlocks.Security.Authorization.Abstractions;

public interface IPermissionChecker
{
    Task<bool> HasPermissionAsync(string permission, CancellationToken ct = default);
}

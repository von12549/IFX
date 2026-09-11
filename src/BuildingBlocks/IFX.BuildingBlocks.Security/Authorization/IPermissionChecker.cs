namespace IFX.BuildingBlocks.Security.Authorization;

public interface IPermissionChecker
{
    Task<bool> HasPermissionAsync(string permission, CancellationToken ct = default);
}

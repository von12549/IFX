using IFX.Platform.Context.Contracts.Context;
namespace IFX.Modules.IAM.Contracts.V1.Authorization;

public interface IResourceAuthorizationContract
{
    Task<ResourceAuthorizationResponse> AuthorizeAsync(ResourceAuthorizationRequest request, ContractRequestContext context, CancellationToken ct = default);
}

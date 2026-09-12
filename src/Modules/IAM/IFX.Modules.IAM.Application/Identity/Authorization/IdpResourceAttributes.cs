using IFX.Modules.IAM.Application.Ports.Authorization;

namespace IFX.Modules.IAM.Application.Identity.Authorization;

public class IdpResourceAttributes : ResourceAttributes
{

    public IdpResourceAttributes(Guid idpId, Guid? tenantId, Guid? createdBy)
    {
        Type = "idp";
        Id = idpId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}

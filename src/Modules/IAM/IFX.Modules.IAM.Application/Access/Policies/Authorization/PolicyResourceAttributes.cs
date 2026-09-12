using IFX.Modules.IAM.Application.Ports.Authorization;

namespace IFX.Modules.IAM.Application.Access.Policies.Authorization;

public class PolicyResourceAttributes : ResourceAttributes
{

    public PolicyResourceAttributes(Guid policyId, Guid? tenantId, Guid? createdById)
    {
        Type = "policy";
        Id = policyId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdById?.ToString() ?? string.Empty;
    }
}

using IFX.BuildingBlocks.Application.Context;

namespace IFX.Modules.IAM.Infrastructure.Access;

public sealed class ExecutionTenantSelection(IExecutionContextAccessor executionContextAccessor)
{
    public Guid? ResolveTenantId()
    {
        if (!executionContextAccessor.HasCurrent)
        {
            return null;
        }

        return executionContextAccessor.Current.TenantId;
    }
}

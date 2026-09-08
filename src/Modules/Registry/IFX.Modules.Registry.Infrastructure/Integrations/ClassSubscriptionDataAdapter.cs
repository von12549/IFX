using IFX.Modules.Registry.Application.Ports;
using IFX.Modules.Registry.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Integrations;

public sealed class ClassSubscriptionDataAdapter(RegistryDbContext context) : IClassSubscriptionDataPort
{
    public async Task<bool> IsClassOpenForSubscriptionAsync(
        Guid classId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        var fundClass = await context.FundClasses.FirstOrDefaultAsync(
            candidate => candidate.Id == classId && candidate.TenantId == tenantId,
            cancellationToken);
        return fundClass?.IsOpenForSubscription() ?? false;
    }
}

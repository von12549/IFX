using IFX.Modules.Registry.Abstractions.DTOs;

namespace IFX.Modules.Registry.Abstractions.Interfaces;

public interface IRegistryReader
{
    Task<FundSummaryDto?> GetFundByIdAsync(Guid fundId, Guid tenantId, CancellationToken ct = default);
    Task<ClassSummaryDto?> GetClassByIdAsync(Guid classId, Guid tenantId, CancellationToken ct = default);
    Task<bool> IsClassOpenForSubscriptionAsync(Guid classId, Guid tenantId, CancellationToken ct = default);
    Task<bool> FundExistsAsync(Guid fundId, Guid tenantId, CancellationToken ct = default);
}

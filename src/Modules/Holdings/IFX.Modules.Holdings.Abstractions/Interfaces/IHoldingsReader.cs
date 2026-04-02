using IFX.Modules.Holdings.Abstractions.DTOs;

namespace IFX.Modules.Holdings.Abstractions.Interfaces;

public interface IHoldingsReader
{
    Task<HoldingSummaryDto?> GetHoldingByIdAsync(Guid holdingId, CancellationToken ct = default);
    Task<IReadOnlyList<HoldingSummaryDto>> GetHoldingsByInvestorAsync(Guid tenantId, Guid investorId, CancellationToken ct = default);
    Task<IReadOnlyList<HoldingSummaryDto>> GetHoldingsByClassAsync(Guid tenantId, Guid classId, CancellationToken ct = default);
}

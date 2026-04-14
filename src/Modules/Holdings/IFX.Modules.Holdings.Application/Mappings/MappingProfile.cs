using AutoMapper;
using IFX.Modules.Holdings.Abstractions.DTOs;
using IFX.Modules.Holdings.Domain.Entities;

namespace IFX.Modules.Holdings.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Holding, HoldingSummaryDto>()
            .ConstructUsing(h => new HoldingSummaryDto(
                h.Id,
                h.TenantId,
                h.InvestmentAccountId,
                h.ClassId,
                h.Units,
                h.Status.ToString(),
                h.LastTransactionAt,
                h.CreatedAt,
                h.UpdatedAt));
    }
}

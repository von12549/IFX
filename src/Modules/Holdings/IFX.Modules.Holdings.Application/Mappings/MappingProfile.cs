using AutoMapper;
using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Domain.Entities;

namespace IFX.Modules.Holdings.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Holding, HoldingSummaryDto>()
            .ForCtorParam(nameof(HoldingSummaryDto.HoldingId), opt => opt.MapFrom(src => src.Id))
            .ForCtorParam(nameof(HoldingSummaryDto.Status), opt => opt.MapFrom(src => src.Status.ToString()));
    }
}

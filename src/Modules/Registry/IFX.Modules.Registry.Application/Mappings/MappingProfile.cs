using AutoMapper;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Domain.Entities;

namespace IFX.Modules.Registry.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Fund, FundDto>()
            .ForMember(dest => dest.FundType, opt => opt.MapFrom(src => src.FundType.ToString()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()));

        CreateMap<FundClass, FundClassDto>()
            .ForMember(dest => dest.NavFrequency, opt => opt.MapFrom(src => src.NavFrequency.ToString()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()))
            .ForMember(dest => dest.IsOpenForSubscription, opt => opt.MapFrom(src => src.IsOpenForSubscription()));
    }
}

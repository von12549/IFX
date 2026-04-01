using AutoMapper;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Party, PartyDto>()
            .ForMember(dest => dest.Type, opt => opt.MapFrom(src => src.Type.ToString()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()));

        CreateMap<Investor, InvestorDto>()
            .ForMember(dest => dest.Type, opt => opt.MapFrom(src => src.Type.ToString()))
            .ForMember(dest => dest.KycStatus, opt => opt.MapFrom(src => src.KycStatus.ToString()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()));
    }
}

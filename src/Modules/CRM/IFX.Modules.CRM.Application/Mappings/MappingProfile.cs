using AutoMapper;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Party, PartyDto>()
            .ForMember(dest => dest.LegalStructure, opt => opt.MapFrom(src => src.LegalStructure.ToString()))
            .ForMember(dest => dest.Roles, opt => opt.MapFrom(src => src.RoleAssignments.Select(r => r.Role.ToString()).ToList()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()));

        CreateMap<Investor, InvestorDto>()
            .ForMember(dest => dest.LegalStructure, opt => opt.MapFrom(src => src.LegalStructure.ToString()))
            .ForMember(dest => dest.KycStatus, opt => opt.MapFrom(src => src.KycStatus.ToString()))
            .ForMember(dest => dest.FatcaCrsStatus, opt => opt.MapFrom(src => src.FatcaCrsStatus.ToString()))
            .ForMember(dest => dest.AmlStatus, opt => opt.MapFrom(src => src.AmlStatus.ToString()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()));

        CreateMap<InvestmentAccount, InvestmentAccountDto>()
            .ForMember(dest => dest.AccountType, opt => opt.MapFrom(src => src.AccountType.ToString()))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()));

        CreateMap<PartyRelationship, PartyRelationshipDto>()
            .ForMember(dest => dest.RelationshipType, opt => opt.MapFrom(src => src.RelationshipType.ToString()))
            .ForMember(dest => dest.EffectiveDate, opt => opt.MapFrom(src => src.EffectiveDate.ToString("yyyy-MM-dd")))
            .ForMember(dest => dest.ExpiryDate, opt => opt.MapFrom(src => src.ExpiryDate.HasValue ? src.ExpiryDate.Value.ToString("yyyy-MM-dd") : null));

        CreateMap<AdvisorInvestmentAccountLink, AdvisorLinkDto>()
            .ForMember(dest => dest.EffectiveDate, opt => opt.MapFrom(src => src.EffectiveDate.ToString("yyyy-MM-dd")))
            .ForMember(dest => dest.ExpiryDate, opt => opt.MapFrom(src => src.ExpiryDate.HasValue ? src.ExpiryDate.Value.ToString("yyyy-MM-dd") : null));

        CreateMap<InvestorDocument, InvestorDocumentDto>()
            .ForMember(dest => dest.DocumentType, opt => opt.MapFrom(src => src.DocumentType.ToString()))
            .ForMember(dest => dest.IssueDate, opt => opt.MapFrom(src => src.IssueDate.HasValue ? src.IssueDate.Value.ToString("yyyy-MM-dd") : null))
            .ForMember(dest => dest.ExpiryDate, opt => opt.MapFrom(src => src.ExpiryDate.HasValue ? src.ExpiryDate.Value.ToString("yyyy-MM-dd") : null));
    }
}

using AutoMapper;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Domain.Entities;

namespace AuthSamples.Modules.Cognito.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<UserRole, UserRoleDto>();
        CreateMap<Idp, IdpDto>();

        CreateMap<User, UserProfileDto>()
            .ForMember(dest => dest.Subject, opt => opt.MapFrom(src => src.Subject.Value))
            .ForMember(dest => dest.Email, opt => opt.MapFrom(src => src.Email.Value))
            .ForMember(dest => dest.Issuer, opt => opt.MapFrom(src => src.Issuer))
            .ForMember(dest => dest.Role, opt => opt.MapFrom(src => src.UserRole));

        CreateMap<LoginEvent, LoginEventDto>()
            .ForMember(dest => dest.DeviceBrowser, opt => opt.MapFrom(src => src.DeviceInfo.Browser))
            .ForMember(dest => dest.DeviceOS, opt => opt.MapFrom(src => src.DeviceInfo.OS));

        CreateMap<UserActivityLog, UserActivityDto>()
            .ForMember(dest => dest.ActivityType, opt => opt.MapFrom(src => src.ActivityType.ToString()));
    }
}

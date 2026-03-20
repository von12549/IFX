using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;

namespace IFX.Modules.Auth.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Role, RoleDto>();
        CreateMap<Role, RoleDetailDto>();
        CreateMap<Permission, PermissionDto>();
        CreateMap<RoleGroup, RoleGroupDto>();
        CreateMap<Idp, IdpDto>();

        CreateMap<User, UserProfileDto>()
            .ForMember(dest => dest.FirstName, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.FirstName : string.Empty))
            .ForMember(dest => dest.LastName, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.LastName : string.Empty))
            .ForMember(dest => dest.BirthDate, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.BirthDate : string.Empty))
            .ForMember(dest => dest.Email, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.Email.Value : string.Empty))
            .ForMember(dest => dest.EmailVerified, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.EmailVerified : false))
            .ForMember(dest => dest.PhoneNumber, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.PhoneNumber : string.Empty))
            .ForMember(dest => dest.Issuer, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.Issuer : string.Empty))
            .ForMember(dest => dest.Roles, opt => opt.MapFrom(src => src.Roles));

        CreateMap<LoginEvent, LoginEventDto>()
            .ForMember(dest => dest.DeviceBrowser, opt => opt.MapFrom(src => src.DeviceInfo.Browser))
            .ForMember(dest => dest.DeviceOS, opt => opt.MapFrom(src => src.DeviceInfo.OS));

        CreateMap<UserActivityLog, UserActivityDto>()
            .ForMember(dest => dest.ActivityType, opt => opt.MapFrom(src => src.ActivityType.ToString()));
    }
}

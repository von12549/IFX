using AutoMapper;
using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Access.Permissions.DTOs;
using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;

namespace IFX.Modules.IAM.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Role, RoleDto>()
            .ForMember(dest => dest.TenantName, opt => opt.MapFrom(src => src.Tenant != null ? src.Tenant.Name : string.Empty));
        CreateMap<Role, RoleDetailDto>()
            .ForMember(dest => dest.TenantName, opt => opt.MapFrom(src => src.Tenant != null ? src.Tenant.Name : string.Empty));
        CreateMap<Permission, PermissionDto>()
            .ForMember(dest => dest.Scope, opt => opt.MapFrom(src =>
                src.Name.StartsWith("Platform.", StringComparison.OrdinalIgnoreCase) ? "Platform" : "Tenant"));
        CreateMap<RoleGroup, RoleGroupDto>()
            .ForMember(dest => dest.TenantName, opt => opt.MapFrom(src => src.Tenant != null ? src.Tenant.Name : string.Empty));
        CreateMap<Idp, IdpDto>()
            .ForMember(dest => dest.TenantName, opt => opt.MapFrom(src => src.Tenant != null ? src.Tenant.Name : string.Empty));
        CreateMap<Tenant, TenantDto>();
        CreateMap<Department, DepartmentDto>()
            .ForMember(dest => dest.TenantName, opt => opt.MapFrom(src => src.Tenant.Name));

        CreateMap<User, UserProfileDto>()
            .ForMember(dest => dest.FirstName, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.FirstName : string.Empty))
            .ForMember(dest => dest.LastName, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.LastName : string.Empty))
            .ForMember(dest => dest.BirthDate, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.BirthDate : string.Empty))
            .ForMember(dest => dest.Email, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.Email.Value : string.Empty))
            .ForMember(dest => dest.EmailVerified, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.EmailVerified : false))
            .ForMember(dest => dest.PhoneNumber, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.PhoneNumber : string.Empty))
            .ForMember(dest => dest.Issuer, opt => opt.MapFrom(src => src.Identities.FirstOrDefault() != null ? src.Identities.FirstOrDefault()!.Issuer : string.Empty))
            .ForMember(dest => dest.Roles, opt => opt.MapFrom(src => src.Roles))
            .ForMember(dest => dest.RoleGroups, opt => opt.MapFrom(src => src.RoleGroups))
            .ForMember(dest => dest.PrimaryTenantId, opt => opt.MapFrom(src => src.PrimaryTenantId))
            .ForMember(dest => dest.Tenants, opt => opt.MapFrom(src => src.Tenants))
            .ForMember(dest => dest.Departments, opt => opt.MapFrom(src => src.Departments))
            .ForMember(dest => dest.GlobalRoles, opt => opt.MapFrom(src =>
                src.GlobalRoles.Select(ugr => ugr.GlobalRole.Name).ToList()));

        CreateMap<LoginEvent, LoginEventDto>()
            .ForMember(dest => dest.DeviceBrowser, opt => opt.MapFrom(src => src.DeviceInfo.Browser))
            .ForMember(dest => dest.DeviceOS, opt => opt.MapFrom(src => src.DeviceInfo.OS));

        CreateMap<UserActivityLog, UserActivityDto>()
            .ForMember(dest => dest.ActivityType, opt => opt.MapFrom(src => src.ActivityType.ToString()));
    }
}

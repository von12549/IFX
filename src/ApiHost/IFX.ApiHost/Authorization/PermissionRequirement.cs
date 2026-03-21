using Microsoft.AspNetCore.Authorization;

namespace IFX.ApiHost.Authorization;

public record PermissionRequirement(string PermissionName) : IAuthorizationRequirement;

using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Users.Endpoints;

public static class UserManagementEndpointExtensions
{
    public static IEndpointRouteBuilder MapUserManagementEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/usermanagement")
            .WithTags("User Management")
            .RequireAuthorization();

        group.MapGet("/users/{userId}", UserManagementEndpoints.GetUserById)
            .WithName("GetUserById")
            .RequirePermission("User.Read")
            .WithSummary("Get a user by ID (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapGet("/users",
            ([AsParameters] UsersParams parameters, IServiceProvider services) =>
                UserManagementEndpoints.GetAllUsers(parameters.page, parameters.pageSize,
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<UserManagementEndpointsLogCategory>>()))
            .WithName("GetAllUsers")
            .RequirePermission("User.Read")
            .WithSummary("Get all users (Admin only, paginated)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        group.MapPut("/users/{userId}", UserManagementEndpoints.UpdateUserProfile)
            .WithName("UpdateUserProfileByAdmin")
            .RequirePermission("User.Write")
            .WithSummary("Update any user's profile (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/users/{userId}/send-test-email", UserManagementEndpoints.SendTestEmail)
            .WithName("SendTestEmail")
            .RequirePermission("User.Write")
            .WithSummary("Send a test email to a user")
            .WithDescription("Enqueues a test email job on the 'email' queue for the specified user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/users/{userId}/roles", UserManagementEndpoints.AssignRolesToUser)
            .WithName("AssignRolesToUser")
            .RequirePermission("User.Write")
            .WithSummary("Assign roles to a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapDelete("/users/{userId}/roles/{roleId}", UserManagementEndpoints.RemoveRoleFromUser)
            .WithName("RemoveRoleFromUser")
            .RequirePermission("User.Write")
            .WithSummary("Remove a role from a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/users/{userId}/rolegroups", UserManagementEndpoints.AssignRoleGroupsToUser)
            .WithName("AssignRoleGroupsToUser")
            .RequirePermission("User.Write")
            .WithSummary("Assign role groups to a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapDelete("/users/{userId}/rolegroups/{roleGroupId}", UserManagementEndpoints.RemoveRoleGroupFromUser)
            .WithName("RemoveRoleGroupFromUser")
            .RequirePermission("User.Write")
            .WithSummary("Remove a role group from a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/users/{userId}/tenants", UserManagementEndpoints.AssignTenantToUser)
            .WithName("AssignTenantToUser")
            .RequirePermission("User.Write")
            .WithSummary("Assign a tenant to a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapDelete("/users/{userId}/tenants/{tenantId}", UserManagementEndpoints.RemoveTenantFromUser)
            .WithName("RemoveTenantFromUser")
            .RequirePermission("User.Write")
            .WithSummary("Remove a tenant from a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/users/{userId}/departments", UserManagementEndpoints.AssignDepartmentToUser)
            .WithName("AssignDepartmentToUser")
            .RequirePermission("User.Write")
            .WithSummary("Assign a department to a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapDelete("/users/{userId}/departments/{departmentId}", UserManagementEndpoints.RemoveDepartmentFromUser)
            .WithName("RemoveDepartmentFromUser")
            .RequirePermission("User.Write")
            .WithSummary("Remove a department from a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        return builder;
    }

    private record UsersParams(int page = 1, int pageSize = 50);
}

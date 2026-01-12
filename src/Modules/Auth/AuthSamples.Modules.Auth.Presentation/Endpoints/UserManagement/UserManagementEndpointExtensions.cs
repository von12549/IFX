using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.UserManagement;

public static class UserManagementEndpointExtensions
{
    public static IEndpointRouteBuilder MapUserManagementEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/usermanagement")
            .WithTags("User Management")
            .RequireAuthorization(policy => policy.RequireRole("Admin"))
            ;

        group.MapGet("/users",
            ([AsParameters] UsersParams parameters, IServiceProvider services) =>
                UserManagementEndpoints.GetAllUsers(parameters.page, parameters.pageSize,
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger>()))
            .WithName("GetAllUsers")
            .WithSummary("Get all users (Admin only, paginated)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        group.MapPut("/users/{userId}", UserManagementEndpoints.UpdateUserProfile)
            .WithName("UpdateUserProfileByAdmin")
            .WithSummary("Update any user's profile (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden)
            .Produces<object>(StatusCodes.Status404NotFound);

        return builder;
    }

    private record UsersParams(int page = 1, int pageSize = 50);
}

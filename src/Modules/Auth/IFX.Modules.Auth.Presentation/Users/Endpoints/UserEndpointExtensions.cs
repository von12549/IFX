using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Auth.Presentation.Endpoints.User;

public static class UserEndpointExtensions
{
    public static IEndpointRouteBuilder MapUserEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/user")
            .WithTags("User")
            .RequireAuthorization()
            ;

        group.MapGet("/profile", UserEndpoints.GetProfile)
            .WithName("GetProfile")
            .WithSummary("Get current user profile")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPut("/profile", UserEndpoints.UpdateProfile)
            .WithName("UpdateProfile")
            .WithSummary("Update current user profile")
            .WithDescription("Updates user profile fields. If email is changed, a verification email is sent automatically.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/login-history",
            ([AsParameters] LoginHistoryParams parameters, HttpContext httpContext, IServiceProvider services) =>
                UserEndpoints.GetLoginHistory(parameters.page, parameters.pageSize,
                    services.GetRequiredService<MediatR.IMediator>(), httpContext))
            .WithName("GetLoginHistory")
            .WithSummary("Get current user login history (paginated)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/activity-log",
            ([AsParameters] ActivityLogParams parameters, HttpContext httpContext, IServiceProvider services) =>
                UserEndpoints.GetActivityLog(parameters.page, parameters.pageSize,
                    services.GetRequiredService<MediatR.IMediator>(), httpContext))
            .WithName("GetActivityLog")
            .WithSummary("Get current user activity log (paginated)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/sync", UserEndpoints.SyncProfile)
            .WithName("SyncProfile")
            .WithSummary("Sync current user profile from Cognito")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }

    private record LoginHistoryParams(int page = 1, int pageSize = 20);
    private record ActivityLogParams(int page = 1, int pageSize = 50);
}

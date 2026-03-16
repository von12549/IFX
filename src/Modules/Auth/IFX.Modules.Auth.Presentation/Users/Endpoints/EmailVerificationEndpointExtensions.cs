using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Users.Endpoints;

public static class EmailVerificationEndpointExtensions
{
    public static IEndpointRouteBuilder MapEmailVerificationEndpoints(this IEndpointRouteBuilder builder)
    {
        // Public endpoints (no authentication required)
        var publicGroup = builder.MapGroup("/api/v1/auth/email")
            .WithTags("Email Verification");

        publicGroup.MapPost("/verify", EmailVerificationEndpoints.VerifyEmail)
            .WithName("VerifyEmail")
            .WithSummary("Verify email address with token or code")
            .WithDescription("Accepts either a verification token (from email link) or a 6-digit code. Returns success if email is verified.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest);

        publicGroup.MapGet("/verify", EmailVerificationEndpoints.VerifyEmailFromLink)
            .WithName("VerifyEmailFromLink")
            .WithSummary("Verify email address from email link")
            .WithDescription("Accepts token and uid query parameters from verification email link.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest);

        // Authenticated endpoints
        var authenticatedGroup = builder.MapGroup("/api/v1/user/email")
            .WithTags("Email Verification")
            .RequireAuthorization();

        authenticatedGroup.MapPost("/send-verification", EmailVerificationEndpoints.SendVerification)
            .WithName("SendEmailVerification")
            .WithSummary("Send email verification to current user")
            .WithDescription("Sends a verification email with code and link to the authenticated user's email address.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        authenticatedGroup.MapPost("/resend-verification", EmailVerificationEndpoints.ResendVerification)
            .WithName("ResendEmailVerification")
            .WithSummary("Resend email verification to current user")
            .WithDescription("Resends a verification email. Rate limited to 3 per hour.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        authenticatedGroup.MapGet("/verification-status", EmailVerificationEndpoints.GetVerificationStatus)
            .WithName("GetEmailVerificationStatus")
            .WithSummary("Get email verification status for current user")
            .WithDescription("Returns the current email and whether it has been verified.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        return builder;
    }
}

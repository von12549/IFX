using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.LogoutUser;

public class LogoutUserCommandValidator : AbstractValidator<LogoutUserCommand>
{
    public LogoutUserCommandValidator()
    {
        RuleFor(x => x.CognitoUserId)
            .NotEmpty().WithMessage("Cognito User ID is required");

        RuleFor(x => x.AccessToken)
            .NotEmpty().WithMessage("Access token is required");

        RuleFor(x => x.IpAddress)
            .NotEmpty().WithMessage("IP address is required");
    }
}

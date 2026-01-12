using FluentValidation;

namespace AuthSamples.Modules.Auth.Application.Commands.LogoutUser;

public class LogoutUserCommandValidator : AbstractValidator<LogoutUserCommand>
{
    public LogoutUserCommandValidator()
    {
        RuleFor(x => x.Subject)
            .NotEmpty().WithMessage("Subject is required");

        RuleFor(x => x.AccessToken)
            .NotEmpty().WithMessage("Access token is required");

        RuleFor(x => x.IpAddress)
            .NotEmpty().WithMessage("IP address is required");
    }
}

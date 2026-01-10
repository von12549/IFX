using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.RefreshToken;

public class RefreshTokenCommandValidator : AbstractValidator<RefreshTokenCommand>
{
    public RefreshTokenCommandValidator()
    {
        RuleFor(x => x.RefreshToken)
            .NotEmpty()
            .WithMessage("Refresh token is required");
        RuleFor(x => x.Username)
            .NotEmpty()
            .WithMessage("Subject is required");
    }
}

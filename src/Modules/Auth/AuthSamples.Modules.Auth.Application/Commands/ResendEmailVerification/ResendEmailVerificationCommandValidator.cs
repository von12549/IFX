using FluentValidation;

namespace AuthSamples.Modules.Auth.Application.Commands.ResendEmailVerification;

public class ResendEmailVerificationCommandValidator : AbstractValidator<ResendEmailVerificationCommand>
{
    public ResendEmailVerificationCommandValidator()
    {
        RuleFor(x => x.UserIdentityId)
            .NotEmpty()
            .WithMessage("User identity ID is required");
    }
}

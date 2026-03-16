using FluentValidation;

namespace IFX.Modules.Auth.Application.Commands.SendEmailVerification;

public class SendEmailVerificationCommandValidator : AbstractValidator<SendEmailVerificationCommand>
{
    public SendEmailVerificationCommandValidator()
    {
        RuleFor(x => x.UserIdentityId)
            .NotEmpty()
            .WithMessage("User identity ID is required");
    }
}

using FluentValidation;

namespace IFX.Modules.IAM.Application.Identity.Commands.SendEmailVerification;

public class SendEmailVerificationCommandValidator : AbstractValidator<SendEmailVerificationCommand>
{
    public SendEmailVerificationCommandValidator()
    {
        RuleFor(x => x.UserIdentityId)
            .NotEmpty()
            .WithMessage("User identity ID is required");
    }
}

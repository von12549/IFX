using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.SyncUser;

public class SyncUserCommandValidator : AbstractValidator<SyncUserCommand>
{
    public SyncUserCommandValidator()
    {
        RuleFor(x => x.Subject)
            .NotEmpty().WithMessage("Subject is required");
    }
}

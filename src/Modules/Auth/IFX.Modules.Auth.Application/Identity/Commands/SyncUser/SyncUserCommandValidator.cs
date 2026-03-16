using FluentValidation;

namespace IFX.Modules.Auth.Application.Identity.Commands.SyncUser;

public class SyncUserCommandValidator : AbstractValidator<SyncUserCommand>
{
    public SyncUserCommandValidator()
    {
        RuleFor(x => x.Subject)
            .NotEmpty().WithMessage("Subject is required");
    }
}

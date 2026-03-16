using FluentValidation;

namespace IFX.Modules.Auth.Application.Commands.SyncUser;

public class SyncUserCommandValidator : AbstractValidator<SyncUserCommand>
{
    public SyncUserCommandValidator()
    {
        RuleFor(x => x.Subject)
            .NotEmpty().WithMessage("Subject is required");
    }
}

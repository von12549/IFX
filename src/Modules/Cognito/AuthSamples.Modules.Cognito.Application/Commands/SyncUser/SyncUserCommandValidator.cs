using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.SyncUser;

public class SyncUserCommandValidator : AbstractValidator<SyncUserCommand>
{
    public SyncUserCommandValidator()
    {
        RuleFor(x => x.CognitoUserId)
            .NotEmpty().WithMessage("Cognito User ID is required");
    }
}

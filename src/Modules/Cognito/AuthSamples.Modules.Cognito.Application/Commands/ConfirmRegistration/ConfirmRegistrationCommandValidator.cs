using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.ConfirmRegistration;

public class ConfirmRegistrationCommandValidator : AbstractValidator<ConfirmRegistrationCommand>
{
    public ConfirmRegistrationCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required")
            .EmailAddress().WithMessage("Invalid email format");

        RuleFor(x => x.ConfirmationCode)
            .NotEmpty().WithMessage("Confirmation code is required");
    }
}

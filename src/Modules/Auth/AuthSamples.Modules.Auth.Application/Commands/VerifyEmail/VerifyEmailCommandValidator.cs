using FluentValidation;

namespace AuthSamples.Modules.Auth.Application.Commands.VerifyEmail;

public class VerifyEmailCommandValidator : AbstractValidator<VerifyEmailCommand>
{
    public VerifyEmailCommandValidator()
    {
        RuleFor(x => x.UserIdentityId)
            .NotEmpty()
            .WithMessage("User identity ID is required");

        RuleFor(x => x)
            .Must(x => !string.IsNullOrEmpty(x.Token) || !string.IsNullOrEmpty(x.Code))
            .WithMessage("Either verification token or code is required");

        When(x => !string.IsNullOrEmpty(x.Code), () =>
        {
            RuleFor(x => x.Code)
                .Length(6)
                .WithMessage("Verification code must be 6 digits")
                .Matches(@"^\d{6}$")
                .WithMessage("Verification code must contain only digits");
        });
    }
}

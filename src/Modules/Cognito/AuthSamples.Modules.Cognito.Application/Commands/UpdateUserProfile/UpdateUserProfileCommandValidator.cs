using FluentValidation;

namespace AuthSamples.Modules.Cognito.Application.Commands.UpdateUserProfile;

public class UpdateUserProfileCommandValidator : AbstractValidator<UpdateUserProfileCommand>
{
    public UpdateUserProfileCommandValidator()
    {
        RuleFor(x => x.CognitoUserId)
            .NotEmpty().WithMessage("CognitoUserId is required");

        // At least one field must be provided
        RuleFor(x => x)
            .Must(command => command.Username != null ||
                           command.FirstName != null ||
                           command.LastName != null ||
                           command.PhoneNumber != null)
            .WithMessage("At least one field must be provided for update");

        // Username validation (if provided)
        When(x => x.Username != null, () =>
        {
            RuleFor(x => x.Username)
                .MinimumLength(3)
                .MaximumLength(50)
                .Matches(@"^[a-zA-Z0-9_-]+$")
                .WithMessage("Username can only contain letters, numbers, hyphens, and underscores");
        });

        // FirstName validation (if provided)
        When(x => x.FirstName != null, () =>
        {
            RuleFor(x => x.FirstName)
                .MaximumLength(100);
        });

        // LastName validation (if provided)
        When(x => x.LastName != null, () =>
        {
            RuleFor(x => x.LastName)
                .MaximumLength(100);
        });

        // PhoneNumber validation (if provided)
        When(x => x.PhoneNumber != null, () =>
        {
            RuleFor(x => x.PhoneNumber)
                .MaximumLength(20)
                .Matches(@"^\+[1-9]\d{1,14}$")
                .WithMessage("Phone number must be in E.164 format (+1234567890)");
        });
    }
}

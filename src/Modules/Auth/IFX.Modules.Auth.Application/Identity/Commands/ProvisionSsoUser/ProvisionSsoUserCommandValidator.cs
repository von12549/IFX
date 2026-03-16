using FluentValidation;

namespace IFX.Modules.Auth.Application.Identity.Commands.ProvisionSsoUser;

public class ProvisionSsoUserCommandValidator : AbstractValidator<ProvisionSsoUserCommand>
{
    public ProvisionSsoUserCommandValidator()
    {
        RuleFor(x => x.IdpId).NotEmpty();
        RuleFor(x => x.Issuer).NotEmpty();
        RuleFor(x => x.Subject).NotEmpty();
        RuleFor(x => x.Email).NotEmpty()
            .WithMessage("Email claim is required for SSO user provisioning");
    }
}

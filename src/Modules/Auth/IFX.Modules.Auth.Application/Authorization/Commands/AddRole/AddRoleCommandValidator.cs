using FluentValidation;

namespace IFX.Modules.Auth.Application.Authorization.Commands.AddRole;

public class AddRoleCommandValidator : AbstractValidator<AddRoleCommand>
{
    public AddRoleCommandValidator()
    {
        RuleFor(x => x.RoleName)
            .NotEmpty().WithMessage("Role name is required")
            .MinimumLength(3)
            .MaximumLength(50)
            .Matches(@"^[a-zA-Z0-9_-]+$")
            .WithMessage("Role name can only contain letters, numbers, hyphens, and underscores");

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required")
            .MaximumLength(255);
    }
}

using FluentValidation;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.CreateRoleGroup;

public class CreateRoleGroupCommandValidator : AbstractValidator<CreateRoleGroupCommand>
{
    public CreateRoleGroupCommandValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Role group name is required")
            .MaximumLength(100);

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required")
            .MaximumLength(255);
    }
}

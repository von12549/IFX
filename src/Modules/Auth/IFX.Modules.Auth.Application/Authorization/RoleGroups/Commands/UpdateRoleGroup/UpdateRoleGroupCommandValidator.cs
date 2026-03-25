using FluentValidation;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.UpdateRoleGroup;

public class UpdateRoleGroupCommandValidator : AbstractValidator<UpdateRoleGroupCommand>
{
    public UpdateRoleGroupCommandValidator()
    {
        RuleFor(x => x.RoleGroupId).NotEmpty();

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Role group name is required")
            .MaximumLength(100);

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required")
            .MaximumLength(255);
    }
}

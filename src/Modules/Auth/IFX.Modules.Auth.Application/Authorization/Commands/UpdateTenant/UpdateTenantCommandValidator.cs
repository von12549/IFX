using FluentValidation;

namespace IFX.Modules.Auth.Application.Authorization.Commands.UpdateTenant;

public class UpdateTenantCommandValidator : AbstractValidator<UpdateTenantCommand>
{
    public UpdateTenantCommandValidator()
    {
        RuleFor(x => x.TenantId)
            .NotEmpty().WithMessage("TenantId is required");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Tenant name is required")
            .MaximumLength(100).WithMessage("Tenant name must not exceed 100 characters");

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("Description is required")
            .MaximumLength(255).WithMessage("Description must not exceed 255 characters");
    }
}

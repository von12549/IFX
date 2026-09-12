using FluentValidation;
using IFX.Modules.IAM.Application.Access.Abac.Registry;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;

public class CreatePolicyCommandValidator : AbstractValidator<CreatePolicyCommand>
{
    public CreatePolicyCommandValidator(IAbacTemplateRegistry templateRegistry)
    {
        RuleFor(x => x).Must(x => PolicyChangeRules.Valid(x.Scope, x.ResourceType, x.Action, x.Conditions))
            .WithMessage("Unsupported policy operation, template or parameter.");
        RuleFor(x => x.TenantId)
            .Must(id => id == null || id != Guid.Empty)
            .WithMessage("TenantId must not be an empty Guid.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required.")
            .MaximumLength(200);

        RuleFor(x => x.Description)
            .MaximumLength(500)
            .When(x => x.Description is not null);

        RuleFor(x => x.ResourceType)
            .NotEmpty().WithMessage("ResourceType is required.")
            .MaximumLength(100);

        RuleFor(x => x.Action)
            .NotEmpty().WithMessage("Action is required.")
            .MaximumLength(100);

        RuleFor(x => x.Conditions)
            .NotEmpty().WithMessage("At least one condition is required.");

        RuleForEach(x => x.Conditions)
            .Must(c => templateRegistry.TryResolve(c.TemplateName, out _))
            .WithMessage((_, c) => $"Template '{c.TemplateName}' is not a registered condition template.");
    }
}

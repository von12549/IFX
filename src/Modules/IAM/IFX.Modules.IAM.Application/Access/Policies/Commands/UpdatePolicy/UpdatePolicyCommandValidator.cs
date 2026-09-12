using FluentValidation;
using IFX.Modules.IAM.Application.Access.Abac.Registry;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.UpdatePolicy;

public class UpdatePolicyCommandValidator : AbstractValidator<UpdatePolicyCommand>
{
    public UpdatePolicyCommandValidator(IAbacTemplateRegistry templateRegistry)
    {
        RuleFor(x => x.PolicyId)
            .NotEmpty().WithMessage("PolicyId is required.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required.")
            .MaximumLength(200);

        RuleFor(x => x.Description)
            .MaximumLength(500)
            .When(x => x.Description is not null);

        RuleFor(x => x.Conditions)
            .NotEmpty().WithMessage("At least one condition is required.");

        RuleForEach(x => x.Conditions)
            .Must(c => templateRegistry.TryResolve(c.TemplateName, out _))
            .WithMessage((_, c) => $"Template '{c.TemplateName}' is not a registered condition template.");
    }
}

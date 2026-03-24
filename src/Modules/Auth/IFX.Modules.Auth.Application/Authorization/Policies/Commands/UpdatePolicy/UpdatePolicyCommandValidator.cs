using FluentValidation;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.UpdatePolicy;

public class UpdatePolicyCommandValidator : AbstractValidator<UpdatePolicyCommand>
{
    public UpdatePolicyCommandValidator(IAbacTemplateRegistry templateRegistry)
    {
        RuleFor(x => x.PolicyId)
            .NotEmpty().WithMessage("PolicyId is required.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required.")
            .MaximumLength(200);

        RuleFor(x => x.Conditions)
            .NotEmpty().WithMessage("At least one condition is required.");

        RuleForEach(x => x.Conditions)
            .Must(c => templateRegistry.TryResolve(c.TemplateName, out _))
            .WithMessage((_, c) => $"Template '{c.TemplateName}' is not a registered condition template.");
    }
}

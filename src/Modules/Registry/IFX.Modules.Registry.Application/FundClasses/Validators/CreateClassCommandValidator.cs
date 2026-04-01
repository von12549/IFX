using FluentValidation;
using IFX.Modules.Registry.Application.FundClasses.Commands.CreateClass;

namespace IFX.Modules.Registry.Application.FundClasses.Validators;

public class CreateClassCommandValidator : AbstractValidator<CreateClassCommand>
{
    public CreateClassCommandValidator()
    {
        RuleFor(x => x.FundId)
            .NotEmpty().WithMessage("FundId is required.");

        RuleFor(x => x.ClassCode)
            .NotEmpty().WithMessage("Class code is required.")
            .MaximumLength(20).WithMessage("Class code must not exceed 20 characters.");

        RuleFor(x => x.ClassName)
            .NotEmpty().WithMessage("Class name is required.")
            .MaximumLength(200).WithMessage("Class name must not exceed 200 characters.");

        RuleFor(x => x.Currency)
            .NotEmpty().WithMessage("Currency is required.")
            .Length(3).WithMessage("Currency must be a 3-letter ISO 4217 code.");
    }
}

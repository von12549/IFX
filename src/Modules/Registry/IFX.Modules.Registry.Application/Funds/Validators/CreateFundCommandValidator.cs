using FluentValidation;
using IFX.Modules.Registry.Application.Funds.Commands.CreateFund;

namespace IFX.Modules.Registry.Application.Funds.Validators;

public class CreateFundCommandValidator : AbstractValidator<CreateFundCommand>
{
    public CreateFundCommandValidator()
    {
        RuleFor(x => x.FundCode)
            .NotEmpty().WithMessage("Fund code is required.")
            .MaximumLength(20).WithMessage("Fund code must not exceed 20 characters.");

        RuleFor(x => x.FundName)
            .NotEmpty().WithMessage("Fund name is required.")
            .MaximumLength(200).WithMessage("Fund name must not exceed 200 characters.");

        RuleFor(x => x.BaseCurrency)
            .NotEmpty().WithMessage("Base currency is required.")
            .Length(3).WithMessage("Base currency must be a 3-letter ISO 4217 code.");
    }
}

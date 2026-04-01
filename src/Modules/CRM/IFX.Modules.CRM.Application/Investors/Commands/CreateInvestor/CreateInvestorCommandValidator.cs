using FluentValidation;

namespace IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;

public class CreateInvestorCommandValidator : AbstractValidator<CreateInvestorCommand>
{
    public CreateInvestorCommandValidator()
    {
        RuleFor(x => x.InvestorCode)
            .NotEmpty().WithMessage("InvestorCode is required.")
            .MaximumLength(20).WithMessage("InvestorCode must not exceed 20 characters.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required.")
            .MaximumLength(200).WithMessage("Name must not exceed 200 characters.");

        RuleFor(x => x.ResidencyCountry)
            .NotEmpty().WithMessage("ResidencyCountry is required.")
            .Length(2).WithMessage("ResidencyCountry must be a 2-letter ISO country code.");

        RuleFor(x => x.TaxResidency)
            .NotEmpty().WithMessage("TaxResidency is required.")
            .Length(2).WithMessage("TaxResidency must be a 2-letter ISO country code.");
    }
}

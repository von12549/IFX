using FluentValidation;
using IFX.Modules.Registry.Application.Products.Commands.CreateProduct;

namespace IFX.Modules.Registry.Application.Products.Validators;

public class CreateProductCommandValidator : AbstractValidator<CreateProductCommand>
{
    public CreateProductCommandValidator()
    {
        RuleFor(x => x.ProductCode)
            .NotEmpty().WithMessage("Product code is required.")
            .MaximumLength(20).WithMessage("Product code must not exceed 20 characters.");

        RuleFor(x => x.ProductName)
            .NotEmpty().WithMessage("Product name is required.")
            .MaximumLength(200).WithMessage("Product name must not exceed 200 characters.");

        RuleFor(x => x.BaseCurrency)
            .NotEmpty().WithMessage("Base currency is required.")
            .Length(3).WithMessage("Base currency must be a 3-letter ISO 4217 code.");

        RuleFor(x => x.ApirCode)
            .MaximumLength(9).WithMessage("APIR code must not exceed 9 characters.")
            .When(x => x.ApirCode != null);

        RuleFor(x => x.Isin)
            .Length(12).WithMessage("ISIN must be exactly 12 characters.")
            .When(x => x.Isin != null);

        RuleFor(x => x.RegulatorSchemeNumber)
            .MaximumLength(20).WithMessage("Regulator scheme number must not exceed 20 characters.")
            .When(x => x.RegulatorSchemeNumber != null);
    }
}

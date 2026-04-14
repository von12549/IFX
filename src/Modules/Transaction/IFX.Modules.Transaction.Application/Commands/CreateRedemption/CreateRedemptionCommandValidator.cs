using FluentValidation;
namespace IFX.Modules.Transaction.Application.Commands.CreateRedemption;
public class CreateRedemptionCommandValidator : AbstractValidator<CreateRedemptionCommand>
{
    public CreateRedemptionCommandValidator()
    {
        RuleFor(x => x.InvestmentAccountId).NotEmpty();
        RuleFor(x => x.FundId).NotEmpty();
        RuleFor(x => x.ClassId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0).WithMessage("Amount must be positive.");
    }
}

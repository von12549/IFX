using FluentValidation;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.CreateInvestmentAccount;

public class CreateInvestmentAccountCommandValidator : AbstractValidator<CreateInvestmentAccountCommand>
{
    public CreateInvestmentAccountCommandValidator()
    {
        RuleFor(x => x.AccountNumber).NotEmpty().MaximumLength(30);
        RuleFor(x => x.AccountType).IsInEnum();
    }
}

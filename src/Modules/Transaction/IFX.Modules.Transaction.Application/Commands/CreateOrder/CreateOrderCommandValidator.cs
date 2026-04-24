using FluentValidation;

namespace IFX.Modules.Transaction.Application.Commands.CreateOrder;

public class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    private static readonly HashSet<string> ValidOrderTypes = new(StringComparer.OrdinalIgnoreCase)
        { "SubscriptionOrder", "RedemptionOrder", "SwitchOrder" };

    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.OrderType).NotEmpty().Must(t => ValidOrderTypes.Contains(t))
            .WithMessage("OrderType must be SubscriptionOrder, RedemptionOrder, or SwitchOrder.");
        RuleFor(x => x.OrderReference).NotEmpty().MaximumLength(35);
        RuleFor(x => x.InvestmentAccountId).NotEmpty();
        RuleFor(x => x.FromFundId).NotEmpty();
        RuleFor(x => x.FromClassId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Currency).NotEmpty().Length(3);
        RuleFor(x => x.TradeDate).NotEmpty();

        When(x => x.OrderType.Equals("SwitchOrder", StringComparison.OrdinalIgnoreCase), () =>
        {
            RuleFor(x => x.ToFundId).NotEmpty().WithMessage("ToFundId is required for SwitchOrder.");
            RuleFor(x => x.ToClassId).NotEmpty().WithMessage("ToClassId is required for SwitchOrder.");
        });
    }
}

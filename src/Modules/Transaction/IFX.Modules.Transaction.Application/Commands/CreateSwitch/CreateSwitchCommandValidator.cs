using FluentValidation;
namespace IFX.Modules.Transaction.Application.Commands.CreateSwitch;
public class CreateSwitchCommandValidator : AbstractValidator<CreateSwitchCommand>
{
    public CreateSwitchCommandValidator()
    {
        RuleFor(x => x.PartyId).NotEmpty();
        RuleFor(x => x.InvestorId).NotEmpty();
        RuleFor(x => x.FundId).NotEmpty();
        RuleFor(x => x.ClassId).NotEmpty();
        RuleFor(x => x.TargetClassId).NotEmpty().WithMessage("TargetClassId is required for Switch.");
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x).Must(x => x.ClassId != x.TargetClassId)
            .WithMessage("Source and target class must differ.");
    }
}

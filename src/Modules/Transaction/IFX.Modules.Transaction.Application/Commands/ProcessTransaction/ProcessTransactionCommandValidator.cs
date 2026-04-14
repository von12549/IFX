using FluentValidation;
namespace IFX.Modules.Transaction.Application.Commands.ProcessTransaction;
public class ProcessTransactionCommandValidator : AbstractValidator<ProcessTransactionCommand>
{
    public ProcessTransactionCommandValidator()
    {
        RuleFor(x => x.TransactionId).NotEmpty();
        RuleFor(x => x.NAVPrice).GreaterThan(0).WithMessage("NAVPrice must be positive.");
    }
}

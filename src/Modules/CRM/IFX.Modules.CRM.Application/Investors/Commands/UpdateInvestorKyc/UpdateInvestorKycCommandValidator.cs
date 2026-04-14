using FluentValidation;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;

public class UpdateInvestorKycCommandValidator : AbstractValidator<UpdateInvestorKycCommand>
{
    public UpdateInvestorKycCommandValidator()
    {
        RuleFor(x => x.KycStatus)
            .Must(status => Enum.IsDefined(typeof(KycStatus), status))
            .WithMessage("KycStatus must be a valid enum value (Pending, Approved, Rejected, Expired).");
    }
}

using FluentValidation;

namespace IFX.Modules.CRM.Application.Parties.Commands.CreateParty;

public class CreatePartyCommandValidator : AbstractValidator<CreatePartyCommand>
{
    public CreatePartyCommandValidator()
    {
        RuleFor(x => x.PartyCode)
            .NotEmpty().WithMessage("PartyCode is required.")
            .MaximumLength(20).WithMessage("PartyCode must not exceed 20 characters.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required.")
            .MaximumLength(200).WithMessage("Name must not exceed 200 characters.");
    }
}

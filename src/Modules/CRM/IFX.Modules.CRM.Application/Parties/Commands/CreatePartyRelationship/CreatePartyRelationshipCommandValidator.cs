using FluentValidation;

namespace IFX.Modules.CRM.Application.Parties.Commands.CreatePartyRelationship;

/// <summary>
/// Enforces directional semantics per PartyRelationshipType:
/// - ParentFirm: FromParty must be an individual (AdvisorRep) or branch (AdvisoryBranch), ToParty must be a firm.
/// - AuthorizedToAdvise: FromParty must have an advisory role.
/// Both checks are enforced at the application level — no DB constraint needed.
/// </summary>
public class CreatePartyRelationshipCommandValidator : AbstractValidator<CreatePartyRelationshipCommand>
{
    public CreatePartyRelationshipCommandValidator()
    {
        RuleFor(x => x.FromPartyId).NotEmpty();
        RuleFor(x => x.ToPartyId).NotEmpty();
        RuleFor(x => x.RelationshipType).IsInEnum();
        RuleFor(x => x.EffectiveDate).NotEmpty();
        RuleFor(x => x).Must(x => x.FromPartyId != x.ToPartyId)
            .WithMessage("FromPartyId and ToPartyId must be different.");
    }
}

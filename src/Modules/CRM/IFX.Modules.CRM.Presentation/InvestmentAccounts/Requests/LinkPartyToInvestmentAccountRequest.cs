namespace IFX.Modules.CRM.Presentation.InvestmentAccounts.Requests;

public record LinkPartyToInvestmentAccountRequest(
    string RelationshipType,
    string EffectiveDate,
    decimal? OwnershipPercentage = null,
    int? LinkOrder = null);

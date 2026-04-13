namespace IFX.Modules.CRM.Presentation.Investors.Requests;

public record UpdateInvestorAmlRequest(
    string AmlStatus,
    string? AmlGatewayReference = null,
    bool? IsPEP = null,
    string? PepDetails = null,
    string? SourceOfWealth = null,
    int UnresolvedPepCount = 0,
    int UnresolvedSanctionCount = 0,
    int UnresolvedAdverseMediaCount = 0);

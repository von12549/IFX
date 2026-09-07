using IFX.Modules.CRM.Domain.Repositories;

namespace IFX.Modules.CRM.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IPartyRepository Parties { get; }
    IInvestorRepository Investors { get; }
    IPartyRoleAssignmentRepository PartyRoleAssignments { get; }
    IInvestmentAccountRepository InvestmentAccounts { get; }
    IPartyInvestmentAccountLinkRepository PartyInvestmentAccountLinks { get; }
    IPartyRelationshipRepository PartyRelationships { get; }
    IAdvisorInvestmentAccountLinkRepository AdvisorInvestmentAccountLinks { get; }
    IInvestorDocumentRepository InvestorDocuments { get; }
    IUserPartyLinkRepository UserPartyLinks { get; }
    IIndividualInvestorProfileRepository IndividualProfiles { get; }
    ICorporateInvestorProfileRepository CorporateProfiles { get; }
    ITrustInvestorProfileRepository TrustProfiles { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}

using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.EntityFrameworkCore.Storage;

namespace IFX.Modules.CRM.Infrastructure.Persistence;

public class CrmUnitOfWork : IUnitOfWork
{
    private readonly CrmDbContext _context;
    private IDbContextTransaction? _transaction;

    public CrmUnitOfWork(
        CrmDbContext context,
        IPartyRepository parties,
        IInvestorRepository investors,
        IPartyRoleAssignmentRepository partyRoleAssignments,
        IInvestmentAccountRepository investmentAccounts,
        IPartyInvestmentAccountLinkRepository partyInvestmentAccountLinks,
        IPartyRelationshipRepository partyRelationships,
        IAdvisorInvestmentAccountLinkRepository advisorInvestmentAccountLinks,
        IInvestorDocumentRepository investorDocuments,
        IUserPartyLinkRepository userPartyLinks,
        IIndividualInvestorProfileRepository individualProfiles,
        ICorporateInvestorProfileRepository corporateProfiles,
        ITrustInvestorProfileRepository trustProfiles)
    {
        _context = context;
        Parties = parties;
        Investors = investors;
        PartyRoleAssignments = partyRoleAssignments;
        InvestmentAccounts = investmentAccounts;
        PartyInvestmentAccountLinks = partyInvestmentAccountLinks;
        PartyRelationships = partyRelationships;
        AdvisorInvestmentAccountLinks = advisorInvestmentAccountLinks;
        InvestorDocuments = investorDocuments;
        UserPartyLinks = userPartyLinks;
        IndividualProfiles = individualProfiles;
        CorporateProfiles = corporateProfiles;
        TrustProfiles = trustProfiles;
    }

    public IPartyRepository Parties { get; }
    public IInvestorRepository Investors { get; }
    public IPartyRoleAssignmentRepository PartyRoleAssignments { get; }
    public IInvestmentAccountRepository InvestmentAccounts { get; }
    public IPartyInvestmentAccountLinkRepository PartyInvestmentAccountLinks { get; }
    public IPartyRelationshipRepository PartyRelationships { get; }
    public IAdvisorInvestmentAccountLinkRepository AdvisorInvestmentAccountLinks { get; }
    public IInvestorDocumentRepository InvestorDocuments { get; }
    public IUserPartyLinkRepository UserPartyLinks { get; }
    public IIndividualInvestorProfileRepository IndividualProfiles { get; }
    public ICorporateInvestorProfileRepository CorporateProfiles { get; }
    public ITrustInvestorProfileRepository TrustProfiles { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default)
    {
        _transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
    }

    public async Task CommitTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public void Dispose()
    {
        _transaction?.Dispose();
        _context.Dispose();
    }
}

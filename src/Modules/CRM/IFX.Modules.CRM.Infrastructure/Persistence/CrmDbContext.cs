using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Persistence;

public class CrmDbContext : DbContext
{
    public CrmDbContext(DbContextOptions<CrmDbContext> options) : base(options)
    {
    }

    public DbSet<Party> Parties => Set<Party>();
    public DbSet<PartyRoleAssignment> PartyRoleAssignments => Set<PartyRoleAssignment>();
    public DbSet<Investor> Investors => Set<Investor>();
    public DbSet<IndividualInvestorProfile> IndividualInvestorProfiles => Set<IndividualInvestorProfile>();
    public DbSet<CorporateInvestorProfile> CorporateInvestorProfiles => Set<CorporateInvestorProfile>();
    public DbSet<TrustInvestorProfile> TrustInvestorProfiles => Set<TrustInvestorProfile>();
    public DbSet<InvestmentAccount> InvestmentAccounts => Set<InvestmentAccount>();
    public DbSet<PartyInvestmentAccountLink> PartyInvestmentAccountLinks => Set<PartyInvestmentAccountLink>();
    public DbSet<PartyRelationship> PartyRelationships => Set<PartyRelationship>();
    public DbSet<AdvisorInvestmentAccountLink> AdvisorInvestmentAccountLinks => Set<AdvisorInvestmentAccountLink>();
    public DbSet<InvestorDocument> InvestorDocuments => Set<InvestorDocument>();
    public DbSet<UserPartyLink> UserPartyLinks => Set<UserPartyLink>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(CrmDbContext).Assembly);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var entries = ChangeTracker.Entries<IAuditableEntity>();

        foreach (var entry in entries)
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedAt = DateTime.UtcNow;
                entry.Entity.UpdatedAt = DateTime.UtcNow;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = DateTime.UtcNow;
            }
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}

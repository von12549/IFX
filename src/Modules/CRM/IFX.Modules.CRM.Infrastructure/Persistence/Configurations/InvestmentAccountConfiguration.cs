using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class InvestmentAccountConfiguration : IEntityTypeConfiguration<InvestmentAccount>
{
    public void Configure(EntityTypeBuilder<InvestmentAccount> builder)
    {
        builder.ToTable("InvestmentAccounts", "crm");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.TenantId).IsRequired();

        builder.Property(a => a.AccountNumber)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(a => a.AccountType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(a => a.CertificateDate);

        builder.Property(a => a.Status)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(a => a.CreatedBy);
        builder.Property(a => a.UpdatedBy);
        builder.Property(a => a.CreatedAt).IsRequired();
        builder.Property(a => a.UpdatedAt).IsRequired();

        builder.HasIndex(a => new { a.TenantId, a.AccountNumber })
            .HasDatabaseName("IX_InvestmentAccounts_TenantId_AccountNumber")
            .IsUnique();

        builder.HasMany(a => a.PartyLinks)
            .WithOne()
            .HasForeignKey(l => l.InvestmentAccountId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(a => a.AdvisorLinks)
            .WithOne()
            .HasForeignKey(l => l.InvestmentAccountId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

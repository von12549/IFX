using IFX.Modules.Holdings.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Holdings.Infrastructure.Persistence.Configurations;

public class HoldingConfiguration : IEntityTypeConfiguration<Holding>
{
    public void Configure(EntityTypeBuilder<Holding> builder)
    {
        builder.ToTable("Holdings", "holdings");
        builder.HasKey(h => h.Id);
        builder.Property(h => h.TenantId).IsRequired();
        builder.Property(h => h.InvestmentAccountId).IsRequired();
        builder.Property(h => h.ClassId).IsRequired();
        builder.Property(h => h.Units).HasPrecision(18, 8).IsRequired();
        builder.Property(h => h.Status).HasConversion<string>().IsRequired();
        builder.Property(h => h.LastTransactionAt);
        builder.Property(h => h.CreatedAt).IsRequired();
        builder.Property(h => h.UpdatedAt).IsRequired().IsConcurrencyToken();

        builder.HasIndex(h => new { h.TenantId, h.InvestmentAccountId, h.ClassId })
            .IsUnique()
            .HasDatabaseName("IX_Holdings_TenantId_InvestmentAccountId_ClassId");

        builder.HasIndex(h => h.TenantId)
            .HasDatabaseName("IX_Holdings_TenantId");

        builder.HasIndex(h => new { h.TenantId, h.ClassId })
            .HasDatabaseName("IX_Holdings_TenantId_ClassId");
    }
}

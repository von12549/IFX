using IFX.Modules.Registry.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Registry.Infrastructure.Persistence.Configurations;

public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.ToTable("Products", "registry");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.TenantId).IsRequired();

        builder.Property(p => p.ProductCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(p => p.ProductName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(p => p.ProductType).IsRequired();

        builder.Property(p => p.BaseCurrency)
            .IsRequired()
            .HasMaxLength(3);

        builder.Property(p => p.ApirCode).HasMaxLength(9);
        builder.Property(p => p.Isin).HasMaxLength(12);
        builder.Property(p => p.RegulatorSchemeNumber).HasMaxLength(20);
        builder.Property(p => p.PdsReference).HasMaxLength(500);
        builder.Property(p => p.IssuerName).HasMaxLength(200);

        builder.Property(p => p.InceptionDate).IsRequired();
        builder.Property(p => p.Status).IsRequired();

        builder.Property(p => p.CreatedBy);
        builder.Property(p => p.CreatedAt).IsRequired();
        builder.Property(p => p.UpdatedAt).IsRequired();

        builder.HasIndex(p => new { p.TenantId, p.ProductCode })
            .HasDatabaseName("IX_Products_TenantId_ProductCode")
            .IsUnique();

        builder.HasMany(p => p.Funds)
            .WithOne(f => f.Product)
            .HasForeignKey(f => f.ProductId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

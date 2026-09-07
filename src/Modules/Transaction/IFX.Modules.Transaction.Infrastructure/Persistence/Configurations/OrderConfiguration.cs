using IFX.Modules.Transaction.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Transaction.Infrastructure.Persistence.Configurations;

public class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("Orders", ModuleDatabase.Schema);
        builder.HasKey(o => o.Id);
        builder.Property(o => o.TenantId).IsRequired();
        builder.Property(o => o.OrderReference).HasMaxLength(35).IsRequired();
        builder.Property(o => o.DealReference).HasMaxLength(350);
        builder.Property(o => o.OrderType).HasConversion<string>().IsRequired();
        builder.Property(o => o.Status).HasConversion<string>().IsRequired();
        builder.Property(o => o.RejectionReason).HasMaxLength(500);
        builder.Property(o => o.CreatedAt).IsRequired();
        builder.Property(o => o.UpdatedAt).IsRequired().IsConcurrencyToken();

        builder.HasIndex(o => o.TenantId)
            .HasDatabaseName("IX_Orders_TenantId");

        builder.HasIndex(o => new { o.TenantId, o.OrderReference })
            .IsUnique()
            .HasDatabaseName("IX_Orders_TenantId_OrderReference");

        builder.HasIndex(o => new { o.TenantId, o.Status })
            .HasDatabaseName("IX_Orders_TenantId_Status");

        // Legs: Transactions where OrderId = this Order.Id
        builder.HasMany(o => o.Legs)
            .WithOne()
            .HasForeignKey(t => t.OrderId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

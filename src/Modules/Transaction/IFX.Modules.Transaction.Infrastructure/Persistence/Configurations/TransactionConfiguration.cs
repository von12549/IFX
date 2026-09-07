using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Infrastructure.Persistence.Configurations;

public class TransactionConfiguration : IEntityTypeConfiguration<TxEntity>
{
    public void Configure(EntityTypeBuilder<TxEntity> builder)
    {
        builder.ToTable("Transactions", "transaction");
        builder.HasKey(t => t.Id);
        builder.Property(t => t.TenantId).IsRequired();
        builder.Property(t => t.Type).HasConversion<string>().IsRequired();
        builder.Property(t => t.InvestmentAccountId).IsRequired();
        builder.Property(t => t.FundId).IsRequired();
        builder.Property(t => t.ClassId).IsRequired();
        builder.Property(t => t.TargetClassId);
        builder.Property(t => t.Amount).HasPrecision(18, 4).IsRequired();
        builder.Property(t => t.Currency).HasMaxLength(3).IsRequired().HasDefaultValue("AUD");
        builder.Property(t => t.Units).HasPrecision(18, 8);
        builder.Property(t => t.NAVPrice).HasPrecision(18, 8);
        builder.Property(t => t.TradeDate).IsRequired();
        builder.Property(t => t.SettlementDate);
        builder.Property(t => t.Status).HasConversion<string>().IsRequired();
        builder.Property(t => t.FailureReason).HasMaxLength(500);

        // Order linkage
        builder.Property(t => t.OrderId);
        builder.Property(t => t.LegId).HasMaxLength(35);

        builder.Property(t => t.CreatedAt).IsRequired();
        builder.Property(t => t.UpdatedAt).IsRequired().IsConcurrencyToken();

        // ExternalFundIdentifier — stored as flat columns
        builder.OwnsOne(t => t.ExternalFundIdentifier, nav =>
        {
            nav.Property(e => e.Type).HasColumnName("ExternalFundIdType").HasMaxLength(10);
            nav.Property(e => e.Identifier).HasColumnName("ExternalFundId").HasMaxLength(35);
            nav.Property(e => e.OtherType).HasColumnName("ExternalFundIdOtherType").HasMaxLength(35);
        });

        // DealingPriceDetails — stored as flat columns
        builder.OwnsOne(t => t.DealingPriceDetails, nav =>
        {
            nav.Property(e => e.PriceType).HasColumnName("PriceType").HasMaxLength(35);
            nav.Property(e => e.Amount).HasColumnName("PriceAmount").HasPrecision(18, 8);
            nav.Property(e => e.Currency).HasColumnName("PriceCurrency").HasMaxLength(3);
        });

        // ChargeDetails, CommissionDetails, TaxDetails — JSON columns
        builder.OwnsMany(t => t.ChargeDetails, nav =>
        {
            nav.ToJson("ChargeDetails");
            nav.Property(e => e.Type).HasMaxLength(35);
            nav.Property(e => e.Rate).HasPrecision(11, 10);
            nav.Property(e => e.Amount).HasPrecision(18, 4);
            nav.Property(e => e.Currency).HasMaxLength(3);
        });

        builder.OwnsMany(t => t.CommissionDetails, nav =>
        {
            nav.ToJson("CommissionDetails");
            nav.Property(e => e.Type).HasMaxLength(35);
            nav.Property(e => e.Rate).HasPrecision(11, 10);
            nav.Property(e => e.Amount).HasPrecision(18, 4);
            nav.Property(e => e.Currency).HasMaxLength(3);
            nav.Property(e => e.PercentageWaived).HasPrecision(11, 10);
        });

        builder.OwnsMany(t => t.TaxDetails, nav =>
        {
            nav.ToJson("TaxDetails");
            nav.Property(e => e.Type).HasMaxLength(35);
            nav.Property(e => e.Rate).HasPrecision(11, 10);
            nav.Property(e => e.Amount).HasPrecision(18, 4);
            nav.Property(e => e.Currency).HasMaxLength(3);
            nav.Property(e => e.ExemptionReason).HasMaxLength(350);
        });

        builder.HasIndex(t => t.TenantId)
            .HasDatabaseName("IX_Transactions_TenantId");

        builder.HasIndex(t => new { t.TenantId, t.InvestmentAccountId })
            .HasDatabaseName("IX_Transactions_TenantId_InvestmentAccountId");

        builder.HasIndex(t => new { t.TenantId, t.Status })
            .HasDatabaseName("IX_Transactions_TenantId_Status");

        builder.HasIndex(t => t.OrderId)
            .HasDatabaseName("IX_Transactions_OrderId");
    }
}

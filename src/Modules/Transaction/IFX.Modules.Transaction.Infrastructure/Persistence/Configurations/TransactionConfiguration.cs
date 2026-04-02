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
        builder.Property(t => t.PartyId).IsRequired();
        builder.Property(t => t.InvestorId).IsRequired();
        builder.Property(t => t.FundId).IsRequired();
        builder.Property(t => t.ClassId).IsRequired();
        builder.Property(t => t.TargetClassId);
        builder.Property(t => t.Amount).HasPrecision(18, 4).IsRequired();
        builder.Property(t => t.Units).HasPrecision(18, 8);
        builder.Property(t => t.NAVPrice).HasPrecision(18, 8);
        builder.Property(t => t.TradeDate).IsRequired();
        builder.Property(t => t.SettlementDate);
        builder.Property(t => t.Status).HasConversion<string>().IsRequired();
        builder.Property(t => t.FailureReason).HasMaxLength(500);
        builder.Property(t => t.CreatedAt).IsRequired();
        builder.Property(t => t.UpdatedAt).IsRequired();
        builder.HasIndex(t => t.TenantId).HasDatabaseName("IX_Transactions_TenantId");
        builder.HasIndex(t => new { t.TenantId, t.InvestorId }).HasDatabaseName("IX_Transactions_TenantId_InvestorId");
        builder.HasIndex(t => new { t.TenantId, t.Status }).HasDatabaseName("IX_Transactions_TenantId_Status");
    }
}

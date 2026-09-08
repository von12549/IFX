using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Holdings.Infrastructure.Messaging;

public sealed class HoldingsInboxConfiguration : IEntityTypeConfiguration<HoldingsInboxMessage>
{
    public void Configure(EntityTypeBuilder<HoldingsInboxMessage> builder)
    {
        builder.ToTable("InboxMessages");
        builder.HasKey(message => message.Id);
        builder.Property(message => message.ConsumerId).HasMaxLength(128).IsRequired();
        builder.Property(message => message.EventType).HasMaxLength(200).IsRequired();
        builder.HasIndex(message => new { message.ConsumerId, message.EventId }).IsUnique();
    }
}

public sealed class HoldingsQuarantinedMessageConfiguration : IEntityTypeConfiguration<HoldingsQuarantinedMessage>
{
    public void Configure(EntityTypeBuilder<HoldingsQuarantinedMessage> builder)
    {
        builder.ToTable("IntegrationEventQuarantine");
        builder.HasKey(message => message.Id);
        builder.Property(message => message.EventType).HasMaxLength(200).IsRequired();
        builder.Property(message => message.ReasonCode).HasMaxLength(128).IsRequired();
        builder.HasIndex(message => message.QuarantinedAt);
    }
}

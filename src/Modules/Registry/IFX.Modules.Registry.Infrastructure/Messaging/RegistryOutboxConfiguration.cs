using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Registry.Infrastructure.Messaging;

public sealed class RegistryOutboxConfiguration : IEntityTypeConfiguration<RegistryOutboxMessage>
{
    public void Configure(EntityTypeBuilder<RegistryOutboxMessage> builder)
    {
        builder.ToTable("OutboxMessages");
        builder.HasKey(message => message.EventId);
        builder.Property(message => message.EventType).HasMaxLength(200).IsRequired();
        builder.Property(message => message.Producer).HasMaxLength(128).IsRequired();
        builder.Property(message => message.Scope).HasMaxLength(16).IsRequired();
        builder.Property(message => message.ContentType).HasMaxLength(64).IsRequired();
        builder.Property(message => message.Provenance).HasMaxLength(24).IsRequired();
        builder.Property(message => message.TraceParent).HasMaxLength(55);
        builder.Property(message => message.TraceState).HasMaxLength(256);
        builder.Property(message => message.PartitionKey).HasMaxLength(100).IsRequired();
        builder.Property(message => message.State).HasMaxLength(24).IsRequired();
        builder.Property(message => message.LastErrorCode).HasMaxLength(128);
        builder.Property(message => message.Payload).IsRequired();
        builder.Property(message => message.ConcurrencyToken).IsRowVersion();
        builder.HasIndex(message => new { message.State, message.NextAttemptAt, message.LeaseUntil });
        builder.HasIndex(message => new { message.PartitionKey, message.Sequence }).IsUnique();
    }
}

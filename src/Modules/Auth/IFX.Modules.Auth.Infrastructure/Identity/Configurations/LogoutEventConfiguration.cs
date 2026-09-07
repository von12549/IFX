using IFX.Modules.Auth.Domain.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Identity.Configurations;

public class LogoutEventConfiguration : IEntityTypeConfiguration<LogoutEvent>
{
    public void Configure(EntityTypeBuilder<LogoutEvent> builder)
    {
        builder.ToTable("LogoutEvents", ModuleDatabase.Schema);

        builder.HasKey(le => le.Id);

        builder.Property(le => le.UserId)
            .IsRequired();

        builder.Property(le => le.LogoutTimestamp)
            .IsRequired();

        builder.Property(le => le.SessionDuration)
            .IsRequired();

        builder.Property(le => le.IpAddress)
            .IsRequired()
            .HasMaxLength(45);

        builder.Property(le => le.Reason)
            .IsRequired()
            .HasMaxLength(100);

        // Indexes
        builder.HasIndex(le => le.UserId);
        builder.HasIndex(le => le.LogoutTimestamp);
    }
}

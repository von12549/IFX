using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Configurations;

public class UserActivityLogConfiguration : IEntityTypeConfiguration<UserActivityLog>
{
    public void Configure(EntityTypeBuilder<UserActivityLog> builder)
    {
        builder.ToTable("UserActivityLogs", "auth");

        builder.HasKey(ual => ual.Id);

        builder.Property(ual => ual.UserId)
            .IsRequired();

        builder.Property(ual => ual.ActivityType)
            .IsRequired()
            .HasConversion<string>()
            .HasMaxLength(50);

        builder.Property(ual => ual.Description)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(ual => ual.Timestamp)
            .IsRequired();

        builder.Property(ual => ual.IpAddress)
            .IsRequired()
            .HasMaxLength(45);

        builder.Property(ual => ual.Metadata)
            .IsRequired()
            .HasColumnType("nvarchar(max)"); // JSON storage

        // Indexes
        builder.HasIndex(ual => ual.UserId);
        builder.HasIndex(ual => ual.Timestamp);
        builder.HasIndex(ual => new { ual.UserId, ual.Timestamp });
    }
}

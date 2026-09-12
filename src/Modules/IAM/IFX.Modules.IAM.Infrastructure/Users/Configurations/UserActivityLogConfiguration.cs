using IFX.Modules.IAM.Domain.Users;
// ActivityType is in IFX.Modules.IAM.Domain.Users (already added)
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Users.Configurations;

public class UserActivityLogConfiguration : IEntityTypeConfiguration<UserActivityLog>
{
    public void Configure(EntityTypeBuilder<UserActivityLog> builder)
    {
        builder.ToTable("UserActivityLogs", ModuleDatabase.Schema);

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

using IFX.Modules.IAM.Domain.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Identity.Configurations;

public class LoginEventConfiguration : IEntityTypeConfiguration<LoginEvent>
{
    public void Configure(EntityTypeBuilder<LoginEvent> builder)
    {
        builder.ToTable("LoginEvents", ModuleDatabase.Schema);

        builder.HasKey(le => le.Id);

        builder.Property(le => le.UserId)
            .IsRequired();

        builder.Property(le => le.LoginTimestamp)
            .IsRequired();

        builder.Property(le => le.Success)
            .IsRequired();

        builder.Property(le => le.FailureReason)
            .HasMaxLength(255);

        builder.Property(le => le.IpAddress)
            .IsRequired()
            .HasMaxLength(45); // IPv6 length

        builder.Property(le => le.UserAgent)
            .IsRequired()
            .HasMaxLength(500);

        // DeviceInfo as owned entity (value object)
        builder.OwnsOne(le => le.DeviceInfo, deviceInfo =>
        {
            deviceInfo.Property(d => d.Browser)
                .HasColumnName("DeviceBrowser")
                .HasMaxLength(100)
                .IsRequired();

            deviceInfo.Property(d => d.OS)
                .HasColumnName("DeviceOS")
                .HasMaxLength(100)
                .IsRequired();

            deviceInfo.Property(d => d.DeviceType)
                .HasColumnName("DeviceType")
                .HasMaxLength(50)
                .IsRequired();

            deviceInfo.Property(d => d.IsBot)
                .HasColumnName("IsBot")
                .IsRequired();
        });

        // Indexes for queries
        builder.HasIndex(le => le.UserId);
        builder.HasIndex(le => le.LoginTimestamp);
        builder.HasIndex(le => new { le.UserId, le.LoginTimestamp });
    }
}

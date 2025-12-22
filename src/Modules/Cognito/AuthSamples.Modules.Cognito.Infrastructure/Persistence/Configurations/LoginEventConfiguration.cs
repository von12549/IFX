using AuthSamples.Modules.Cognito.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Configurations;

public class LoginEventConfiguration : IEntityTypeConfiguration<LoginEvent>
{
    public void Configure(EntityTypeBuilder<LoginEvent> builder)
    {
        builder.ToTable("LoginEvents", "cognito");

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

        builder.Property(le => le.CognitoSessionId)
            .HasMaxLength(100);

        builder.Property(le => le.AccessToken)
            .HasMaxLength(2048); // JWT tokens can be long

        builder.Property(le => le.RefreshToken)
            .HasMaxLength(2048);

        builder.Property(le => le.TokenExpiresAt);

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

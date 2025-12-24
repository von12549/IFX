using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users", "cognito");

        builder.HasKey(u => u.Id);

        // CognitoUserId value object conversion
        builder.Property(u => u.CognitoUserId)
            .HasConversion(
                v => v.Value,
                v => CognitoUserId.Create(v))
            .IsRequired()
            .HasMaxLength(100)
            .HasColumnName("CognitoUserId");

        builder.HasIndex(u => u.CognitoUserId).IsUnique();

        // EmailAddress value object conversion
        builder.Property(u => u.Email)
            .HasConversion(
                v => v.Value,
                v => EmailAddress.Create(v))
            .IsRequired()
            .HasMaxLength(255)
            .HasColumnName("Email");

        builder.HasIndex(u => u.Email).IsUnique();

        builder.Property(u => u.Username)
            .IsRequired()
            .HasMaxLength(50);

        builder.HasIndex(u => u.Username).IsUnique();

        builder.Property(u => u.FirstName)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(u => u.LastName)
            .IsRequired()
            .HasMaxLength(100);
        builder.Property(u => u.BirthDate)
            .IsRequired()
            .HasMaxLength(10);

        builder.Property(u => u.PhoneNumber)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(u => u.EmailVerified)
            .IsRequired();

        builder.Property(u => u.PhoneNumberVerified)
            .IsRequired();

        builder.Property(u => u.IsActive)
            .IsRequired();

        builder.Property(u => u.LastSyncedAt)
            .IsRequired();

        builder.Property(u => u.CreatedAt)
            .IsRequired();

        builder.Property(u => u.UpdatedAt)
            .IsRequired();

        // Ignore navigation properties loaded separately
        builder.Ignore(u => u.LoginEvents);
    }
}

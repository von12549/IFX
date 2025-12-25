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

        // Ignore value object properties first
        builder.Ignore(u => u.CognitoUserId);
        builder.Ignore(u => u.Email);

        // Configure backing fields as shadow properties
        builder.Property<string>("_cognitoUserId")
            .HasColumnName("CognitoUserId")
            .IsRequired()
            .HasMaxLength(100);

        builder.HasIndex("_cognitoUserId")
            .HasDatabaseName("IX_Users_CognitoUserId")
            .IsUnique();

        builder.Property<string>("_email")
            .HasColumnName("Email")
            .IsRequired()
            .HasMaxLength(255);

        builder.HasIndex("_email")
            .HasDatabaseName("IX_Users_Email")
            .IsUnique();

        builder.Property(u => u.Username)
            .IsRequired()
            .HasMaxLength(50);

        builder.HasIndex("Username").IsUnique();

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

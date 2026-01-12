using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.ValueObjects;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users", "auth");

        builder.HasKey(u => u.Id);

        // Ignore value object properties first
        builder.Ignore(u => u.Subject);
        builder.Ignore(u => u.Email);

        // Configure backing fields as shadow properties
        builder.Property<string>("_subject")
            .HasColumnName("Subject")
            .IsRequired()
            .HasMaxLength(100);

        builder.HasIndex("_subject")
            .HasDatabaseName("IX_Users_Subject")
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

        // Configure UserRole relationship
        builder.Property(u => u.UserRoleId)
            .IsRequired();

        builder.HasOne(u => u.UserRole)
            .WithMany()
            .HasForeignKey(u => u.UserRoleId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(u => u.UserRoleId)
            .HasDatabaseName("IX_Users_UserRoleId");

        // Configure Issuer
        builder.Property(u => u.Issuer)
            .IsRequired()
            .HasMaxLength(500)
            .HasDefaultValue("https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P");

        // Ignore navigation properties loaded separately
        builder.Ignore(u => u.LoginEvents);
    }
}

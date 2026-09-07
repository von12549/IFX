using IFX.Modules.Auth.Domain.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Identity.Configurations;

public class UserIdentityConfiguration : IEntityTypeConfiguration<UserIdentity>
{
    public void Configure(EntityTypeBuilder<UserIdentity> builder)
    {
        builder.ToTable("UserIdentities", ModuleDatabase.Schema);

        builder.HasKey(ui => ui.Id);

        // Ignore value object properties first
        builder.Ignore(ui => ui.Subject);
        builder.Ignore(ui => ui.Email);

        // Configure backing fields as shadow properties
        builder.Property<string>("_subject")
            .HasColumnName("Subject")
            .IsRequired()
            .HasMaxLength(100);

        builder.Property<string>("_email")
            .HasColumnName("Email")
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(ui => ui.Issuer)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(ui => ui.FirstName)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(ui => ui.LastName)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(ui => ui.BirthDate)
            .IsRequired()
            .HasMaxLength(10);

        builder.Property(ui => ui.PhoneNumber)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(ui => ui.EmailVerified)
            .IsRequired();

        builder.Property(ui => ui.PhoneNumberVerified)
            .IsRequired();

        builder.Property(ui => ui.LastSyncedAt)
            .IsRequired();

        builder.Property(ui => ui.CreatedBy);

        builder.Property(ui => ui.CreatedAt)
            .IsRequired();

        builder.Property(ui => ui.UpdatedAt)
            .IsRequired();

        // Configure UserId foreign key
        builder.Property(ui => ui.UserId)
            .IsRequired();

        builder.HasOne(ui => ui.User)
            .WithMany(u => u.Identities)
            .HasForeignKey(ui => ui.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(ui => ui.UserId)
            .HasDatabaseName("IX_UserIdentities_UserId");

        // Configure IdpId foreign key
        builder.Property(ui => ui.IdpId)
            .IsRequired();

        builder.HasOne(ui => ui.Idp)
            .WithMany()
            .HasForeignKey(ui => ui.IdpId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(ui => ui.IdpId)
            .HasDatabaseName("IX_UserIdentities_IdpId");

        // Unique constraint on (Issuer, Subject)
        builder.HasIndex(new[] { nameof(UserIdentity.Issuer), "_subject" })
            .HasDatabaseName("UQ_UserIdentity_Issuer_Subject")
            .IsUnique();
    }
}

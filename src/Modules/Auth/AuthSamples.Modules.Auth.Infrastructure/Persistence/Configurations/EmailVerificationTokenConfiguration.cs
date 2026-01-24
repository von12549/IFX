using AuthSamples.Modules.Auth.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Configurations;

public class EmailVerificationTokenConfiguration : IEntityTypeConfiguration<EmailVerificationToken>
{
    public void Configure(EntityTypeBuilder<EmailVerificationToken> builder)
    {
        builder.ToTable("EmailVerificationTokens", "auth");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.Email)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(e => e.TokenHash)
            .IsRequired()
            .HasMaxLength(64); // SHA256 = 64 hex chars

        builder.Property(e => e.Code)
            .IsRequired()
            .HasMaxLength(6);

        builder.Property(e => e.ExpiresAt)
            .IsRequired();

        builder.Property(e => e.IsUsed)
            .IsRequired();

        builder.Property(e => e.UsedAt);

        builder.Property(e => e.CreatedAt)
            .IsRequired();

        builder.Property(e => e.UpdatedAt)
            .IsRequired();

        // Configure UserIdentityId foreign key
        builder.Property(e => e.UserIdentityId)
            .IsRequired();

        builder.HasOne(e => e.UserIdentity)
            .WithMany()
            .HasForeignKey(e => e.UserIdentityId)
            .OnDelete(DeleteBehavior.Cascade);

        // Unique index on TokenHash for fast lookup
        builder.HasIndex(e => e.TokenHash)
            .HasDatabaseName("UQ_EmailVerificationTokens_TokenHash")
            .IsUnique();

        // Composite index for code lookup (UserIdentityId + Code)
        builder.HasIndex(e => new { e.UserIdentityId, e.Code })
            .HasDatabaseName("IX_EmailVerificationTokens_UserIdentityId_Code");

        // Index on ExpiresAt for cleanup job
        builder.HasIndex(e => e.ExpiresAt)
            .HasDatabaseName("IX_EmailVerificationTokens_ExpiresAt");

        // Index on UserIdentityId for fetching active tokens
        builder.HasIndex(e => e.UserIdentityId)
            .HasDatabaseName("IX_EmailVerificationTokens_UserIdentityId");
    }
}

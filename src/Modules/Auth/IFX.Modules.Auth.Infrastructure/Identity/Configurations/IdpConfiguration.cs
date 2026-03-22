using IFX.Modules.Auth.Domain.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Identity.Configurations;

public class IdpConfiguration : IEntityTypeConfiguration<Idp>
{
    public void Configure(EntityTypeBuilder<Idp> builder)
    {
        builder.ToTable("Idps", "auth");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(i => i.Issuer)
            .IsRequired()
            .HasMaxLength(500);

        builder.HasIndex(i => i.Issuer)
            .HasDatabaseName("IX_Idps_Issuer")
            .IsUnique();

        builder.Property(i => i.Description)
            .HasMaxLength(1000);

        builder.Property(i => i.LoginUrl)
            .HasMaxLength(500);

        builder.Property(i => i.IdpType)
            .IsRequired()
            .HasDefaultValue(IdpType.Internal)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(i => i.IsPrimary)
            .IsRequired()
            .HasDefaultValue(false);

        // Unique filtered index: only one IdP can be primary
        builder.HasIndex(i => i.IsPrimary)
            .HasDatabaseName("IX_Idps_IsPrimary")
            .HasFilter("[IsPrimary] = 1")
            .IsUnique();

        builder.Property(i => i.Enabled)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(i => i.AutoProvisionEnabled)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(i => i.Authority)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(i => i.ExpectedAudiences)
            .HasMaxLength(2000)
            .HasDefaultValue("[]");

        builder.Property(i => i.AllowedAlgs)
            .HasMaxLength(500)
            .HasDefaultValue("[]");

        builder.Property(i => i.RequiredScopes)
            .HasMaxLength(1000)
            .HasDefaultValue("[]");

        builder.Property(i => i.ClaimMapping)
            .HasMaxLength(4000)
            .HasDefaultValue("{}");

        builder.Property(i => i.ClockSkewSeconds)
            .IsRequired()
            .HasDefaultValue(300);

        builder.Property(i => i.CreatedAt)
            .IsRequired();

        builder.Property(i => i.UpdatedAt)
            .IsRequired();

        // Index for common queries
        builder.HasIndex(i => i.Enabled);

        builder.Property(i => i.TenantId).IsRequired();

        builder.HasOne<IFX.Modules.Auth.Domain.Authorization.Tenant>()
            .WithMany()
            .HasForeignKey(i => i.TenantId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

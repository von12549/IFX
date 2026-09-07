using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class UserPartyLinkConfiguration : IEntityTypeConfiguration<UserPartyLink>
{
    public void Configure(EntityTypeBuilder<UserPartyLink> builder)
    {
        builder.ToTable("UserPartyLinks", ModuleDatabase.Schema);

        builder.HasKey(l => l.Id);

        builder.Property(l => l.TenantId).IsRequired();

        // Cross-schema value reference — no FK constraint to auth.Users
        builder.Property(l => l.UserId).IsRequired();

        builder.Property(l => l.PartyId).IsRequired();

        // One user maps to exactly one Party per tenant
        builder.HasIndex(l => new { l.TenantId, l.UserId })
            .HasDatabaseName("IX_UserPartyLinks_TenantId_UserId")
            .IsUnique();

        // No UNIQUE on PartyId — multiple users can share a corporate party
        builder.HasIndex(l => new { l.TenantId, l.PartyId })
            .HasDatabaseName("IX_UserPartyLinks_TenantId_PartyId");
    }
}

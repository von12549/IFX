using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class PartyConfiguration : IEntityTypeConfiguration<Party>
{
    public void Configure(EntityTypeBuilder<Party> builder)
    {
        builder.ToTable("Parties", ModuleDatabase.Schema);

        builder.HasKey(p => p.Id);

        builder.Property(p => p.TenantId).IsRequired();

        builder.Property(p => p.PartyCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(p => p.Name)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(p => p.LegalStructure)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(p => p.Status)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(p => p.CreatedBy);
        builder.Property(p => p.UpdatedBy);
        builder.Property(p => p.CreatedAt).IsRequired();
        builder.Property(p => p.UpdatedAt).IsRequired();

        builder.HasIndex(p => new { p.TenantId, p.PartyCode })
            .HasDatabaseName("IX_Parties_TenantId_PartyCode")
            .IsUnique();

        builder.HasMany(p => p.RoleAssignments)
            .WithOne(r => r.Party)
            .HasForeignKey(r => r.PartyId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Access.Configurations;

public class GlobalRoleConfiguration : IEntityTypeConfiguration<GlobalRole>
{
    public void Configure(EntityTypeBuilder<GlobalRole> builder)
    {
        builder.ToTable("GlobalRoles", ModuleDatabase.Schema);

        builder.HasKey(gr => gr.Id);

        builder.Property(gr => gr.Name)
            .HasMaxLength(100)
            .IsRequired();

        builder.Property(gr => gr.Description)
            .HasMaxLength(500)
            .IsRequired();

        builder.Property(gr => gr.CreatedAt).IsRequired();
        builder.Property(gr => gr.UpdatedAt).IsRequired();

        builder.HasIndex(gr => gr.Name)
            .IsUnique()
            .HasDatabaseName("UX_GlobalRoles_Name");

        builder.HasMany(gr => gr.UserGlobalRoles)
            .WithOne(ugr => ugr.GlobalRole)
            .HasForeignKey(ugr => ugr.GlobalRoleId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

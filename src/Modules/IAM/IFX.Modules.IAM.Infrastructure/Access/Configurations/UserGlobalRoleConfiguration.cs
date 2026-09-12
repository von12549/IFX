using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Access.Configurations;

public class UserGlobalRoleConfiguration : IEntityTypeConfiguration<UserGlobalRole>
{
    public void Configure(EntityTypeBuilder<UserGlobalRole> builder)
    {
        builder.ToTable("UserGlobalRoles", ModuleDatabase.Schema);

        builder.HasKey(ugr => new { ugr.UserId, ugr.GlobalRoleId });

        builder.Property(ugr => ugr.AssignedAt).IsRequired();

        builder.HasOne(ugr => ugr.User)
            .WithMany(u => u.GlobalRoles)
            .HasForeignKey(ugr => ugr.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // GlobalRole → UserGlobalRoles configured on GlobalRoleConfiguration
    }
}

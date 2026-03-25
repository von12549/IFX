using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Configurations;

public class UserGlobalRoleConfiguration : IEntityTypeConfiguration<UserGlobalRole>
{
    public void Configure(EntityTypeBuilder<UserGlobalRole> builder)
    {
        builder.ToTable("UserGlobalRoles", "auth");

        builder.HasKey(ugr => new { ugr.UserId, ugr.GlobalRoleId });

        builder.Property(ugr => ugr.AssignedAt).IsRequired();

        builder.HasOne(ugr => ugr.User)
            .WithMany(u => u.GlobalRoles)
            .HasForeignKey(ugr => ugr.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // GlobalRole → UserGlobalRoles configured on GlobalRoleConfiguration
    }
}

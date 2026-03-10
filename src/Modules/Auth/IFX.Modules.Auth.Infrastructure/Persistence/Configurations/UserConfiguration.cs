using IFX.Modules.Auth.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users", "auth");

        builder.HasKey(u => u.Id);

        builder.Property(u => u.IsActive)
            .IsRequired();

        builder.Property(u => u.DisplayName)
            .IsRequired()
            .HasMaxLength(200);

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

        // Configure Identities navigation (inverse of UserIdentity.User)
        builder.HasMany(u => u.Identities)
            .WithOne(ui => ui.User)
            .HasForeignKey(ui => ui.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // Ignore navigation properties loaded separately
        builder.Ignore(u => u.LoginEvents);
    }
}

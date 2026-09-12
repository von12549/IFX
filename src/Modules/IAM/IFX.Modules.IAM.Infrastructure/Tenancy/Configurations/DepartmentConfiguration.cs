using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Tenancy.Configurations;

public class DepartmentConfiguration : IEntityTypeConfiguration<Department>
{
    public void Configure(EntityTypeBuilder<Department> builder)
    {
        builder.ToTable("Departments", ModuleDatabase.Schema);

        builder.HasKey(d => d.Id);

        builder.Property(d => d.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(d => d.Description)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(d => d.TenantId).IsRequired();

        builder.HasIndex(d => new { d.TenantId, d.Name })
            .HasDatabaseName("IX_Departments_TenantId_Name")
            .IsUnique();

        builder.HasOne(d => d.Tenant)
            .WithMany()
            .HasForeignKey(d => d.TenantId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Property(d => d.CreatedBy);
        builder.Property(d => d.CreatedAt).IsRequired();
        builder.Property(d => d.UpdatedAt).IsRequired();
    }
}

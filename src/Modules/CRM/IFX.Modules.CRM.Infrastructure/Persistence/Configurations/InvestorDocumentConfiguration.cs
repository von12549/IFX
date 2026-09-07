using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class InvestorDocumentConfiguration : IEntityTypeConfiguration<InvestorDocument>
{
    public void Configure(EntityTypeBuilder<InvestorDocument> builder)
    {
        builder.ToTable("InvestorDocuments", ModuleDatabase.Schema);

        builder.HasKey(d => d.Id);

        builder.Property(d => d.TenantId).IsRequired();
        builder.Property(d => d.InvestorId).IsRequired();

        builder.Property(d => d.DocumentType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(d => d.DocumentNumber)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(d => d.IssueCountry)
            .IsRequired()
            .HasMaxLength(2);

        builder.Property(d => d.IssueState)
            .HasMaxLength(50);

        builder.Property(d => d.IssueDate);
        builder.Property(d => d.ExpiryDate);

        builder.HasIndex(d => new { d.TenantId, d.InvestorId })
            .HasDatabaseName("IX_InvestorDocuments_TenantId_InvestorId");
    }
}

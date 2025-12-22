using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Configurations;

public class RegistrationFlowEventConfiguration : IEntityTypeConfiguration<RegistrationFlowEvent>
{
    public void Configure(EntityTypeBuilder<RegistrationFlowEvent> builder)
    {
        builder.ToTable("RegistrationFlowEvents", "cognito");

        builder.HasKey(rfe => rfe.Id);

        builder.Property(rfe => rfe.Email)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(rfe => rfe.Username)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(rfe => rfe.RegistrationInitiatedAt)
            .IsRequired();

        builder.Property(rfe => rfe.RegistrationConfirmedAt);

        builder.Property(rfe => rfe.Status)
            .IsRequired()
            .HasConversion<string>()
            .HasMaxLength(50);

        builder.Property(rfe => rfe.ConfirmationCode)
            .HasMaxLength(100);

        builder.Property(rfe => rfe.FailureReason)
            .HasMaxLength(500);

        builder.Property(rfe => rfe.IpAddress)
            .IsRequired()
            .HasMaxLength(45);

        builder.Property(rfe => rfe.UserId);

        // Indexes
        builder.HasIndex(rfe => rfe.Email);
        builder.HasIndex(rfe => rfe.Status);
        builder.HasIndex(rfe => rfe.RegistrationInitiatedAt);
    }
}

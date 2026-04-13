using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class IndividualInvestorProfile : BaseEntity, IAuditableEntity
{
    public Guid InvestorId { get; private set; }
    public DateOnly? DateOfBirth { get; private set; }
    public DateOnly? DateOfDeath { get; private set; }
    public Gender? Gender { get; private set; }
    public string? PlaceOfBirth { get; private set; }
    public string? Nationality { get; private set; }
    public string? IdDocumentType { get; private set; }
    public string? IdDocumentNumber { get; private set; }
    public string? IdDocumentCountry { get; private set; }
    public DateOnly? IdDocumentExpiry { get; private set; }
    public string? FrankieOneEntityId { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Investor Investor { get; private set; } = null!;

    private IndividualInvestorProfile() { }

    public static IndividualInvestorProfile Create(
        Guid investorId,
        DateOnly? dateOfBirth = null,
        Gender? gender = null,
        string? nationality = null,
        string? placeOfBirth = null,
        string? idDocumentType = null,
        string? idDocumentNumber = null,
        string? idDocumentCountry = null,
        DateOnly? idDocumentExpiry = null,
        string? frankieOneEntityId = null)
    {
        if (investorId == Guid.Empty)
            throw new ArgumentException("InvestorId must be provided.", nameof(investorId));

        return new IndividualInvestorProfile
        {
            InvestorId = investorId,
            DateOfBirth = dateOfBirth,
            Gender = gender,
            Nationality = nationality?.Trim().ToUpperInvariant(),
            PlaceOfBirth = placeOfBirth?.Trim(),
            IdDocumentType = idDocumentType?.Trim(),
            IdDocumentNumber = idDocumentNumber?.Trim(),
            IdDocumentCountry = idDocumentCountry?.Trim().ToUpperInvariant(),
            IdDocumentExpiry = idDocumentExpiry,
            FrankieOneEntityId = frankieOneEntityId?.Trim()
        };
    }

    public void Update(
        DateOnly? dateOfBirth,
        Gender? gender,
        string? nationality,
        string? placeOfBirth,
        string? idDocumentType,
        string? idDocumentNumber,
        string? idDocumentCountry,
        DateOnly? idDocumentExpiry,
        string? frankieOneEntityId)
    {
        DateOfBirth = dateOfBirth;
        Gender = gender;
        Nationality = nationality?.Trim().ToUpperInvariant();
        PlaceOfBirth = placeOfBirth?.Trim();
        IdDocumentType = idDocumentType?.Trim();
        IdDocumentNumber = idDocumentNumber?.Trim();
        IdDocumentCountry = idDocumentCountry?.Trim().ToUpperInvariant();
        IdDocumentExpiry = idDocumentExpiry;
        FrankieOneEntityId = frankieOneEntityId?.Trim();
    }
}

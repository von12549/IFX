using IFX.BuildingBlocks.Domain;

namespace IFX.Modules.CRM.Domain.Entities;

public class CorporateInvestorProfile : BaseEntity, IAuditableEntity
{
    public Guid InvestorId { get; private set; }
    public string? Acn { get; private set; }
    public string? Abn { get; private set; }
    public string? RegistrationNumber { get; private set; }
    public string? CountryOfIncorporation { get; private set; }
    public DateOnly? IncorporationDate { get; private set; }
    public bool? IsPubliclyListed { get; private set; }
    public string? Regulator { get; private set; }
    public string? LicenceNumber { get; private set; }
    public string? FrankieOneEntityId { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Investor Investor { get; private set; } = null!;

    private CorporateInvestorProfile() { }

    public static CorporateInvestorProfile Create(
        Guid investorId,
        string? acn = null,
        string? abn = null,
        string? registrationNumber = null,
        string? countryOfIncorporation = null,
        DateOnly? incorporationDate = null,
        bool? isPubliclyListed = null,
        string? regulator = null,
        string? licenceNumber = null,
        string? frankieOneEntityId = null)
    {
        if (investorId == Guid.Empty)
            throw new ArgumentException("InvestorId must be provided.", nameof(investorId));

        return new CorporateInvestorProfile
        {
            InvestorId = investorId,
            Acn = acn?.Trim(),
            Abn = abn?.Trim(),
            RegistrationNumber = registrationNumber?.Trim(),
            CountryOfIncorporation = countryOfIncorporation?.Trim().ToUpperInvariant(),
            IncorporationDate = incorporationDate,
            IsPubliclyListed = isPubliclyListed,
            Regulator = regulator?.Trim(),
            LicenceNumber = licenceNumber?.Trim(),
            FrankieOneEntityId = frankieOneEntityId?.Trim()
        };
    }

    public void Update(
        string? acn, string? abn, string? registrationNumber,
        string? countryOfIncorporation, DateOnly? incorporationDate,
        bool? isPubliclyListed, string? regulator, string? licenceNumber,
        string? frankieOneEntityId)
    {
        Acn = acn?.Trim();
        Abn = abn?.Trim();
        RegistrationNumber = registrationNumber?.Trim();
        CountryOfIncorporation = countryOfIncorporation?.Trim().ToUpperInvariant();
        IncorporationDate = incorporationDate;
        IsPubliclyListed = isPubliclyListed;
        Regulator = regulator?.Trim();
        LicenceNumber = licenceNumber?.Trim();
        FrankieOneEntityId = frankieOneEntityId?.Trim();
    }
}

using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Tests.Entities;

public class InvestorTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private const string ValidCode = "INV001";
    private const string ValidName = "John Doe";
    private const string ValidCountry = "AU";
    private const string ValidTaxResidency = "AU";

    [Fact]
    public void Create_WithValidParameters_ReturnsInvestor()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);

        investor.Should().NotBeNull();
        investor.Id.Should().NotBeEmpty();
        investor.TenantId.Should().Be(ValidTenantId);
        investor.InvestorCode.Should().Be(ValidCode);
        investor.Name.Should().Be(ValidName);
        investor.Type.Should().Be(InvestorType.Individual);
        investor.KycStatus.Should().Be(KycStatus.Pending);
        investor.Status.Should().Be(EntityStatus.Active);
        investor.KycReviewedAt.Should().BeNull();
    }

    [Fact]
    public void Create_NormalizesCountryToUpperCase()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, "au", "au");

        investor.ResidencyCountry.Should().Be("AU");
        investor.TaxResidency.Should().Be("AU");
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Investor.Create(Guid.Empty, ValidCode, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyInvestorCode_ThrowsArgumentException(string code)
    {
        var act = () => Investor.Create(ValidTenantId, code, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);

        act.Should().Throw<ArgumentException>().WithParameterName("investorCode");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyResidencyCountry_ThrowsArgumentException(string country)
    {
        var act = () => Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, country, ValidTaxResidency);

        act.Should().Throw<ArgumentException>().WithParameterName("residencyCountry");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyTaxResidency_ThrowsArgumentException(string taxResidency)
    {
        var act = () => Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, ValidCountry, taxResidency);

        act.Should().Throw<ArgumentException>().WithParameterName("taxResidency");
    }

    [Fact]
    public void UpdateKyc_SetsKycStatusAndTimestamp()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);
        var before = DateTime.UtcNow;

        investor.UpdateKyc(KycStatus.Approved);

        investor.KycStatus.Should().Be(KycStatus.Approved);
        investor.KycReviewedAt.Should().NotBeNull();
        investor.KycReviewedAt.Should().BeOnOrAfter(before);
    }

    [Fact]
    public void UpdateKyc_CanTransitionToRejected()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);

        investor.UpdateKyc(KycStatus.Rejected);

        investor.KycStatus.Should().Be(KycStatus.Rejected);
        investor.KycReviewedAt.Should().NotBeNull();
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesFields()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);

        investor.Update("Jane Doe", InvestorType.Corporate, "nz", "nz");

        investor.Name.Should().Be("Jane Doe");
        investor.Type.Should().Be(InvestorType.Corporate);
        investor.ResidencyCountry.Should().Be("NZ");
        investor.TaxResidency.Should().Be("NZ");
    }

    [Fact]
    public void Close_SetsStatusToClosed()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, InvestorType.Individual, ValidCountry, ValidTaxResidency);

        investor.Close();

        investor.Status.Should().Be(EntityStatus.Closed);
    }
}

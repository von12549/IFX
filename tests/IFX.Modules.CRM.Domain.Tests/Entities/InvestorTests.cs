using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Tests.Entities;

public class InvestorTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private const string ValidCode = "INV001";
    private const string ValidName = "John Doe";

    [Fact]
    public void Create_WithValidParameters_ReturnsInvestor()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.Should().NotBeNull();
        investor.Id.Should().NotBeEmpty();
        investor.TenantId.Should().Be(ValidTenantId);
        investor.InvestorCode.Should().Be(ValidCode);
        investor.Name.Should().Be(ValidName);
        investor.LegalStructure.Should().Be(PartyLegalStructure.Individual);
        investor.KycStatus.Should().Be(KycStatus.Pending);
        investor.Status.Should().Be(EntityStatus.Active);
        investor.KycReviewedAt.Should().BeNull();
    }

    [Fact]
    public void Create_WithTaxResidencyCountry_NormalizesToUpperCase()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual, "au");

        investor.TaxResidencyCountry.Should().Be("AU");
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Investor.Create(Guid.Empty, ValidCode, ValidName, PartyLegalStructure.Individual);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyInvestorCode_ThrowsArgumentException(string code)
    {
        var act = () => Investor.Create(ValidTenantId, code, ValidName, PartyLegalStructure.Individual);

        act.Should().Throw<ArgumentException>().WithParameterName("investorCode");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyName_ThrowsArgumentException(string name)
    {
        var act = () => Investor.Create(ValidTenantId, ValidCode, name, PartyLegalStructure.Individual);

        act.Should().Throw<ArgumentException>().WithParameterName("name");
    }

    [Fact]
    public void UpdateKyc_SetsKycStatusAndTimestamp()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);
        var before = DateTime.UtcNow;

        investor.UpdateKyc(KycStatus.Approved);

        investor.KycStatus.Should().Be(KycStatus.Approved);
        investor.KycReviewedAt.Should().NotBeNull();
        investor.KycReviewedAt.Should().BeOnOrAfter(before);
    }

    [Fact]
    public void UpdateKyc_CanTransitionToRejected()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.UpdateKyc(KycStatus.Rejected);

        investor.KycStatus.Should().Be(KycStatus.Rejected);
        investor.KycReviewedAt.Should().NotBeNull();
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesFields()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.Update("Jane Doe", "NZ", null, null);

        investor.Name.Should().Be("Jane Doe");
        investor.TaxResidencyCountry.Should().Be("NZ");
    }

    [Fact]
    public void Close_SetsStatusToClosed()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.Close();

        investor.Status.Should().Be(EntityStatus.Closed);
    }

    [Fact]
    public void UpdateAmlStatus_SetsAmlFieldsCorrectly()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.UpdateAmlStatus(AmlStatus.Review, "REF-001", true, "Government official", "Salary", 0, 1, 0);

        investor.AmlStatus.Should().Be(AmlStatus.Review);
        investor.AmlGatewayReference.Should().Be("REF-001");
        investor.IsPEP.Should().BeTrue();
        investor.PepDetails.Should().Be("Government official");
        investor.SourceOfWealth.Should().Be("Salary");
        investor.UnresolvedSanctionCount.Should().Be(1);
    }

    [Fact]
    public void UpdateAmlStatus_DefaultsToNotChecked()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.AmlStatus.Should().Be(AmlStatus.NotChecked);
    }

    [Fact]
    public void UpdateAmlStatus_BlockedStatus_SetsAmlStatusToBlocked()
    {
        var investor = Investor.Create(ValidTenantId, ValidCode, ValidName, PartyLegalStructure.Individual);

        investor.UpdateAmlStatus(AmlStatus.Blocked);

        investor.AmlStatus.Should().Be(AmlStatus.Blocked);
    }
}

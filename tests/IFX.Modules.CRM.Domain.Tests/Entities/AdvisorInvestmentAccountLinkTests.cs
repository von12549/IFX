using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Tests.Entities;

public class AdvisorInvestmentAccountLinkTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private static readonly Guid AdvisorId = Guid.NewGuid();
    private static readonly Guid AccountId = Guid.NewGuid();
    private static readonly DateOnly Today = DateOnly.FromDateTime(DateTime.UtcNow);

    [Fact]
    public void Create_WithValidParameters_ReturnsLink()
    {
        var link = AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today);

        link.Should().NotBeNull();
        link.Id.Should().NotBeEmpty();
        link.TenantId.Should().Be(ValidTenantId);
        link.AdvisorPartyId.Should().Be(AdvisorId);
        link.InvestmentAccountId.Should().Be(AccountId);
        link.EffectiveDate.Should().Be(Today);
        link.ExpiryDate.Should().BeNull();
        link.RebateRate.Should().BeNull();
    }

    [Fact]
    public void Create_WithRebateRate_StoresRebateRate()
    {
        var link = AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today, 1.5m);

        link.RebateRate.Should().Be(1.5m);
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => AdvisorInvestmentAccountLink.Create(Guid.Empty, AdvisorId, AccountId, Today);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Fact]
    public void Create_WithEmptyAdvisorId_ThrowsArgumentException()
    {
        var act = () => AdvisorInvestmentAccountLink.Create(ValidTenantId, Guid.Empty, AccountId, Today);

        act.Should().Throw<ArgumentException>().WithParameterName("advisorPartyId");
    }

    [Fact]
    public void Create_WithEmptyAccountId_ThrowsArgumentException()
    {
        var act = () => AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, Guid.Empty, Today);

        act.Should().Throw<ArgumentException>().WithParameterName("investmentAccountId");
    }

    [Theory]
    [InlineData(-0.01)]
    [InlineData(100.01)]
    public void Create_WithInvalidRebateRate_ThrowsArgumentException(double rate)
    {
        var act = () => AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today, (decimal)rate);

        act.Should().Throw<ArgumentException>().WithParameterName("rebateRate");
    }

    [Fact]
    public void Expire_SetsExpiryDate()
    {
        var link = AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today);
        var expiry = Today.AddDays(30);

        link.Expire(expiry);

        link.ExpiryDate.Should().Be(expiry);
    }

    [Fact]
    public void IsActive_BeforeEffectiveDate_ReturnsFalse()
    {
        var link = AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today);

        link.IsActive(Today.AddDays(-1)).Should().BeFalse();
    }

    [Fact]
    public void IsActive_OnEffectiveDate_ReturnsTrue()
    {
        var link = AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today);

        link.IsActive(Today).Should().BeTrue();
    }

    [Fact]
    public void IsActive_AfterExpiry_ReturnsFalse()
    {
        var link = AdvisorInvestmentAccountLink.Create(ValidTenantId, AdvisorId, AccountId, Today);
        link.Expire(Today.AddDays(5));

        link.IsActive(Today.AddDays(6)).Should().BeFalse();
    }
}

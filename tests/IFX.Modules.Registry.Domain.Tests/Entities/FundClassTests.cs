using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;

namespace IFX.Modules.Registry.Domain.Tests.Entities;

public class FundClassTests
{
    private static readonly Guid ValidFundId = Guid.NewGuid();
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private const string ValidCode = "CLASS-A";
    private const string ValidName = "Class A";
    private const string ValidCurrency = "USD";

    [Fact]
    public void Create_WithValidParameters_ReturnsFundClass()
    {
        var cls = FundClass.Create(ValidFundId, ValidTenantId, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);

        cls.Should().NotBeNull();
        cls.Id.Should().NotBeEmpty();
        cls.FundId.Should().Be(ValidFundId);
        cls.TenantId.Should().Be(ValidTenantId);
        cls.ClassCode.Should().Be("CLASS-A");
        cls.ClassName.Should().Be(ValidName);
        cls.Currency.Should().Be(ValidCurrency);
        cls.NavFrequency.Should().Be(NavFrequency.Daily);
        cls.Status.Should().Be(ClassStatus.Active);
        cls.MinInitialInvestment.Should().BeNull();
        cls.ManagementFeeRate.Should().BeNull();
        cls.PerformanceFeeRate.Should().BeNull();
    }

    [Fact]
    public void Create_NormalizesCodeAndCurrencyToUpperCase()
    {
        var cls = FundClass.Create(ValidFundId, ValidTenantId, "class-a", ValidName, "usd", NavFrequency.Daily);

        cls.ClassCode.Should().Be("CLASS-A");
        cls.Currency.Should().Be("USD");
    }

    [Fact]
    public void Create_WithEmptyFundId_ThrowsArgumentException()
    {
        var act = () => FundClass.Create(Guid.Empty, ValidTenantId, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);

        act.Should().Throw<ArgumentException>().WithParameterName("fundId");
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => FundClass.Create(ValidFundId, Guid.Empty, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("US")]
    [InlineData("USDD")]
    public void Create_WithInvalidCurrency_ThrowsArgumentException(string currency)
    {
        var act = () => FundClass.Create(ValidFundId, ValidTenantId, ValidCode, ValidName, currency, NavFrequency.Daily);

        act.Should().Throw<ArgumentException>().WithParameterName("currency");
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesFundClass()
    {
        var cls = FundClass.Create(ValidFundId, ValidTenantId, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);

        cls.Update("Class B", "EUR", 10000m, 0.015m, 0.20m, NavFrequency.Weekly);

        cls.ClassName.Should().Be("Class B");
        cls.Currency.Should().Be("EUR");
        cls.MinInitialInvestment.Should().Be(10000m);
        cls.ManagementFeeRate.Should().Be(0.015m);
        cls.PerformanceFeeRate.Should().Be(0.20m);
        cls.NavFrequency.Should().Be(NavFrequency.Weekly);
    }

    [Fact]
    public void IsOpenForSubscription_WhenActive_ReturnsTrue()
    {
        var cls = FundClass.Create(ValidFundId, ValidTenantId, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);

        cls.IsOpenForSubscription().Should().BeTrue();
    }

    [Fact]
    public void IsOpenForSubscription_WhenClosed_ReturnsFalse()
    {
        var cls = FundClass.Create(ValidFundId, ValidTenantId, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);
        cls.Close();

        cls.IsOpenForSubscription().Should().BeFalse();
    }

    [Fact]
    public void Close_SetsStatusToClosed()
    {
        var cls = FundClass.Create(ValidFundId, ValidTenantId, ValidCode, ValidName, ValidCurrency, NavFrequency.Daily);

        cls.Close();

        cls.Status.Should().Be(ClassStatus.Closed);
    }
}

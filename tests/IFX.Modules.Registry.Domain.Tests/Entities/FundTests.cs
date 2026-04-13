using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;

namespace IFX.Modules.Registry.Domain.Tests.Entities;

public class FundTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private static readonly DateOnly ValidInceptionDate = new(2024, 1, 1);
    private const string ValidCode = "FUND001";
    private const string ValidName = "Growth Fund";
    private const string ValidCurrency = "USD";

    [Fact]
    public void Create_WithValidParameters_ReturnsFund()
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        fund.Should().NotBeNull();
        fund.Id.Should().NotBeEmpty();
        fund.TenantId.Should().Be(ValidTenantId);
        fund.FundCode.Should().Be(ValidCode);
        fund.FundName.Should().Be(ValidName);
        fund.FundType.Should().Be(FundType.UCITS);
        fund.BaseCurrency.Should().Be(ValidCurrency);
        fund.InceptionDate.Should().Be(ValidInceptionDate);
        fund.Status.Should().Be(FundStatus.Active);
    }

    [Fact]
    public void Create_NormalizesFundCodeToUpperCase()
    {
        var fund = Fund.Create(ValidTenantId, "fund001", ValidName, FundType.UCITS, "usd", ValidInceptionDate);

        fund.FundCode.Should().Be("FUND001");
        fund.BaseCurrency.Should().Be("USD");
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Fund.Create(Guid.Empty, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyFundCode_ThrowsArgumentException(string code)
    {
        var act = () => Fund.Create(ValidTenantId, code, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("fundCode");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyFundName_ThrowsArgumentException(string name)
    {
        var act = () => Fund.Create(ValidTenantId, ValidCode, name, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("fundName");
    }

    [Theory]
    [InlineData("")]
    [InlineData("US")]
    [InlineData("USDD")]
    public void Create_WithInvalidCurrency_ThrowsArgumentException(string currency)
    {
        var act = () => Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, currency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("baseCurrency");
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesFund()
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        fund.Update("Updated Fund Name", FundType.AIF, "EUR");

        fund.FundName.Should().Be("Updated Fund Name");
        fund.FundType.Should().Be(FundType.AIF);
        fund.BaseCurrency.Should().Be("EUR");
    }

    [Theory]
    [InlineData("")]
    [InlineData("US")]
    public void Update_WithInvalidCurrency_ThrowsArgumentException(string currency)
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        var act = () => fund.Update(ValidName, FundType.UCITS, currency);

        act.Should().Throw<ArgumentException>().WithParameterName("baseCurrency");
    }

    [Fact]
    public void Close_SetsStatusToClosed()
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        fund.Close();

        fund.Status.Should().Be(FundStatus.Closed);
    }

    [Fact]
    public void SetProduct_AssignsProductId()
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);
        var productId = Guid.NewGuid();

        fund.SetProduct(productId);

        fund.ProductId.Should().Be(productId);
    }

    [Fact]
    public void SetProduct_WithNull_ClearsProductId()
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);
        fund.SetProduct(Guid.NewGuid());

        fund.SetProduct(null);

        fund.ProductId.Should().BeNull();
    }

    [Fact]
    public void Create_HasNullProductIdByDefault()
    {
        var fund = Fund.Create(ValidTenantId, ValidCode, ValidName, FundType.UCITS, ValidCurrency, ValidInceptionDate);

        fund.ProductId.Should().BeNull();
    }
}

using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;

namespace IFX.Modules.Registry.Domain.Tests.Entities;

public class ProductTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private static readonly DateOnly ValidInceptionDate = new(2024, 1, 1);
    private const string ValidCode = "PROD001";
    private const string ValidName = "Growth Managed Fund";
    private const string ValidCurrency = "AUD";

    [Fact]
    public void Create_WithValidParameters_ReturnsProduct()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        product.Should().NotBeNull();
        product.Id.Should().NotBeEmpty();
        product.TenantId.Should().Be(ValidTenantId);
        product.ProductCode.Should().Be(ValidCode);
        product.ProductName.Should().Be(ValidName);
        product.ProductType.Should().Be(ProductType.ManagedFund);
        product.BaseCurrency.Should().Be(ValidCurrency);
        product.InceptionDate.Should().Be(ValidInceptionDate);
        product.Status.Should().Be(ProductStatus.Active);
    }

    [Fact]
    public void Create_NormalizesCodeAndCurrencyToUpperCase()
    {
        var product = Product.Create(ValidTenantId, "prod001", ValidName, ProductType.ETF, "aud", ValidInceptionDate);

        product.ProductCode.Should().Be("PROD001");
        product.BaseCurrency.Should().Be("AUD");
    }

    [Fact]
    public void Create_WithOptionalFields_SetsNormalisedValues()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate,
            apirCode: "abc1234", isin: "AU000XYZ1234", regulatorSchemeNumber: "ARSN123", pdsReference: "pds-ref", issuerName: "Fund Manager Co");

        product.ApirCode.Should().Be("ABC1234");
        product.Isin.Should().Be("AU000XYZ1234");
        product.RegulatorSchemeNumber.Should().Be("ARSN123");
        product.PdsReference.Should().Be("pds-ref");
        product.IssuerName.Should().Be("Fund Manager Co");
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Product.Create(Guid.Empty, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyProductCode_ThrowsArgumentException(string code)
    {
        var act = () => Product.Create(ValidTenantId, code, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("productCode");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyProductName_ThrowsArgumentException(string name)
    {
        var act = () => Product.Create(ValidTenantId, ValidCode, name, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("productName");
    }

    [Theory]
    [InlineData("")]
    [InlineData("AU")]
    [InlineData("AUDD")]
    public void Create_WithInvalidCurrency_ThrowsArgumentException(string currency)
    {
        var act = () => Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, currency, ValidInceptionDate);

        act.Should().Throw<ArgumentException>().WithParameterName("baseCurrency");
    }

    [Fact]
    public void Create_WithNullOptionalFields_LeavesThemNull()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        product.ApirCode.Should().BeNull();
        product.Isin.Should().BeNull();
        product.RegulatorSchemeNumber.Should().BeNull();
        product.PdsReference.Should().BeNull();
        product.IssuerName.Should().BeNull();
        product.WindUpDate.Should().BeNull();
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesFields()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);
        var windUp = new DateOnly(2030, 12, 31);

        product.Update("New Name", "abc1234", "AU000XYZ1234", "ARSN999", "pds-v2", "New Issuer", windUp);

        product.ProductName.Should().Be("New Name");
        product.ApirCode.Should().Be("ABC1234");
        product.Isin.Should().Be("AU000XYZ1234");
        product.RegulatorSchemeNumber.Should().Be("ARSN999");
        product.PdsReference.Should().Be("pds-v2");
        product.IssuerName.Should().Be("New Issuer");
        product.WindUpDate.Should().Be(windUp);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Update_WithEmptyName_ThrowsArgumentException(string name)
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        var act = () => product.Update(name, null, null, null, null, null, null);

        act.Should().Throw<ArgumentException>().WithParameterName("productName");
    }

    [Fact]
    public void Update_ClearsOptionalFieldsWhenPassedNull()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate,
            apirCode: "ABC1234", issuerName: "Old Issuer");

        product.Update(ValidName, null, null, null, null, null, null);

        product.ApirCode.Should().BeNull();
        product.IssuerName.Should().BeNull();
    }

    [Fact]
    public void Close_SetsStatusToClosed()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        product.Close();

        product.Status.Should().Be(ProductStatus.Closed);
    }

    [Fact]
    public void Suspend_SetsStatusToSuspended()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        product.Suspend();

        product.Status.Should().Be(ProductStatus.Suspended);
    }

    [Fact]
    public void Reactivate_SetsStatusToActive()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);
        product.Close();

        product.Reactivate();

        product.Status.Should().Be(ProductStatus.Active);
    }

    [Fact]
    public void Create_InitiallyHasEmptyFundsCollection()
    {
        var product = Product.Create(ValidTenantId, ValidCode, ValidName, ProductType.ManagedFund, ValidCurrency, ValidInceptionDate);

        product.Funds.Should().BeEmpty();
    }
}

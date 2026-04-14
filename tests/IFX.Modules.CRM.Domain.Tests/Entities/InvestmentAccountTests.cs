using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Tests.Entities;

public class InvestmentAccountTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private const string ValidAccountNumber = "ACC001";

    [Fact]
    public void Create_WithValidParameters_ReturnsAccount()
    {
        var account = InvestmentAccount.Create(ValidTenantId, ValidAccountNumber, InvestmentAccountType.Individual);

        account.Should().NotBeNull();
        account.Id.Should().NotBeEmpty();
        account.TenantId.Should().Be(ValidTenantId);
        account.AccountNumber.Should().Be("ACC001");
        account.AccountType.Should().Be(InvestmentAccountType.Individual);
        account.Status.Should().Be(EntityStatus.Active);
        account.CertificateDate.Should().BeNull();
    }

    [Fact]
    public void Create_NormalizesAccountNumberToUpperCase()
    {
        var account = InvestmentAccount.Create(ValidTenantId, "acc001", InvestmentAccountType.Individual);

        account.AccountNumber.Should().Be("ACC001");
    }

    [Fact]
    public void Create_WithCertificateDate_StoresCertificateDate()
    {
        var certDate = new DateOnly(2024, 1, 15);
        var account = InvestmentAccount.Create(ValidTenantId, ValidAccountNumber, InvestmentAccountType.Trust, certDate);

        account.CertificateDate.Should().Be(certDate);
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => InvestmentAccount.Create(Guid.Empty, ValidAccountNumber, InvestmentAccountType.Individual);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyAccountNumber_ThrowsArgumentException(string number)
    {
        var act = () => InvestmentAccount.Create(ValidTenantId, number, InvestmentAccountType.Individual);

        act.Should().Throw<ArgumentException>().WithParameterName("accountNumber");
    }

    [Fact]
    public void Deactivate_SetsStatusToInactive()
    {
        var account = InvestmentAccount.Create(ValidTenantId, ValidAccountNumber, InvestmentAccountType.Individual);

        account.Deactivate();

        account.Status.Should().Be(EntityStatus.Inactive);
    }

    [Fact]
    public void Lock_SetsStatusToLocked()
    {
        var account = InvestmentAccount.Create(ValidTenantId, ValidAccountNumber, InvestmentAccountType.Individual);

        account.Lock();

        account.Status.Should().Be(EntityStatus.Locked);
    }

    [Fact]
    public void Activate_SetsStatusToActive()
    {
        var account = InvestmentAccount.Create(ValidTenantId, ValidAccountNumber, InvestmentAccountType.Individual);
        account.Deactivate();

        account.Activate();

        account.Status.Should().Be(EntityStatus.Active);
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesFields()
    {
        var account = InvestmentAccount.Create(ValidTenantId, ValidAccountNumber, InvestmentAccountType.Individual);
        var newDate = new DateOnly(2025, 6, 1);

        account.Update("ACC002", InvestmentAccountType.Trust, newDate);

        account.AccountNumber.Should().Be("ACC002");
        account.AccountType.Should().Be(InvestmentAccountType.Trust);
        account.CertificateDate.Should().Be(newDate);
    }
}

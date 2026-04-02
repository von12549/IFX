using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Tests.Entities;

public class PartyTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private const string ValidCode = "PTY001";
    private const string ValidName = "Acme Fund Ltd";

    [Fact]
    public void Create_WithValidParameters_ReturnsParty()
    {
        var party = Party.Create(ValidTenantId, ValidCode, ValidName, PartyType.FundManager);

        party.Should().NotBeNull();
        party.Id.Should().NotBeEmpty();
        party.TenantId.Should().Be(ValidTenantId);
        party.PartyCode.Should().Be(ValidCode);
        party.Name.Should().Be(ValidName);
        party.Type.Should().Be(PartyType.FundManager);
        party.Status.Should().Be(EntityStatus.Active);
    }

    [Fact]
    public void Create_TrimsWhitespace()
    {
        var party = Party.Create(ValidTenantId, "  PTY002  ", "  Trimmed Name  ", PartyType.Distributor);

        party.PartyCode.Should().Be("PTY002");
        party.Name.Should().Be("Trimmed Name");
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Party.Create(Guid.Empty, ValidCode, ValidName, PartyType.FundManager);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyPartyCode_ThrowsArgumentException(string code)
    {
        var act = () => Party.Create(ValidTenantId, code, ValidName, PartyType.FundManager);

        act.Should().Throw<ArgumentException>().WithParameterName("partyCode");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_WithEmptyName_ThrowsArgumentException(string name)
    {
        var act = () => Party.Create(ValidTenantId, ValidCode, name, PartyType.FundManager);

        act.Should().Throw<ArgumentException>().WithParameterName("name");
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesParty()
    {
        var party = Party.Create(ValidTenantId, ValidCode, ValidName, PartyType.FundManager);

        party.Update("New Name", PartyType.Distributor);

        party.Name.Should().Be("New Name");
        party.Type.Should().Be(PartyType.Distributor);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Update_WithEmptyName_ThrowsArgumentException(string name)
    {
        var party = Party.Create(ValidTenantId, ValidCode, ValidName, PartyType.FundManager);

        var act = () => party.Update(name, PartyType.FundManager);

        act.Should().Throw<ArgumentException>().WithParameterName("name");
    }

    [Fact]
    public void Close_SetsStatusToClosed()
    {
        var party = Party.Create(ValidTenantId, ValidCode, ValidName, PartyType.FundManager);
        party.Status.Should().Be(EntityStatus.Active);

        party.Close();

        party.Status.Should().Be(EntityStatus.Closed);
    }
}

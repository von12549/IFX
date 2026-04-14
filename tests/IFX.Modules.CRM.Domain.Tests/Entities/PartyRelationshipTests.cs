using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Tests.Entities;

public class PartyRelationshipTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private static readonly Guid FromPartyId = Guid.NewGuid();
    private static readonly Guid ToPartyId = Guid.NewGuid();
    private static readonly DateOnly Today = DateOnly.FromDateTime(DateTime.UtcNow);

    [Fact]
    public void Create_WithValidParameters_ReturnsRelationship()
    {
        var rel = PartyRelationship.Create(ValidTenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        rel.Should().NotBeNull();
        rel.Id.Should().NotBeEmpty();
        rel.TenantId.Should().Be(ValidTenantId);
        rel.FromPartyId.Should().Be(FromPartyId);
        rel.ToPartyId.Should().Be(ToPartyId);
        rel.RelationshipType.Should().Be(PartyRelationshipType.AuthorizedToAdvise);
        rel.EffectiveDate.Should().Be(Today);
        rel.ExpiryDate.Should().BeNull();
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => PartyRelationship.Create(Guid.Empty, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Fact]
    public void Create_WithEmptyFromPartyId_ThrowsArgumentException()
    {
        var act = () => PartyRelationship.Create(ValidTenantId, Guid.Empty, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        act.Should().Throw<ArgumentException>().WithParameterName("fromPartyId");
    }

    [Fact]
    public void Create_WithEmptyToPartyId_ThrowsArgumentException()
    {
        var act = () => PartyRelationship.Create(ValidTenantId, FromPartyId, Guid.Empty, PartyRelationshipType.AuthorizedToAdvise, Today);

        act.Should().Throw<ArgumentException>().WithParameterName("toPartyId");
    }

    [Fact]
    public void Create_WhenFromAndToPartySame_ThrowsArgumentException()
    {
        var act = () => PartyRelationship.Create(ValidTenantId, FromPartyId, FromPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Expire_SetsExpiryDate()
    {
        var rel = PartyRelationship.Create(ValidTenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        var expiry = Today.AddDays(30);

        rel.Expire(expiry);

        rel.ExpiryDate.Should().Be(expiry);
    }

    [Fact]
    public void Expire_IsIdempotent()
    {
        var rel = PartyRelationship.Create(ValidTenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        rel.Expire(Today.AddDays(10));

        rel.Expire(Today.AddDays(5));

        rel.ExpiryDate.Should().Be(Today.AddDays(5));
    }

    [Fact]
    public void IsActive_BeforeEffectiveDate_ReturnsFalse()
    {
        var rel = PartyRelationship.Create(ValidTenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        rel.IsActive(Today.AddDays(-1)).Should().BeFalse();
    }

    [Fact]
    public void IsActive_OnEffectiveDate_ReturnsTrue()
    {
        var rel = PartyRelationship.Create(ValidTenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        rel.IsActive(Today).Should().BeTrue();
    }

    [Fact]
    public void IsActive_AfterExpiry_ReturnsFalse()
    {
        var rel = PartyRelationship.Create(ValidTenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        rel.Expire(Today.AddDays(5));

        rel.IsActive(Today.AddDays(6)).Should().BeFalse();
    }
}

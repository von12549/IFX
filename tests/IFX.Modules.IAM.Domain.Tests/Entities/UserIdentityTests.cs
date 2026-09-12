using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;

namespace IFX.Modules.IAM.Domain.Tests.Entities;

public class UserIdentityTests
{
    [Fact]
    public void Create_WithValidParameters_ReturnsUserIdentity()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var idpId = Guid.NewGuid();
        var issuer = TestConstants.IFXCognitoIssuer;
        var subject = Subject.Create(TestConstants.ValidSubject);
        var email = EmailAddress.Create(TestConstants.ValidEmail);

        // Act
        var userIdentity = UserIdentity.Create(
            userId,
            idpId,
            issuer,
            subject,
            email,
            TestConstants.ValidFirstName,
            TestConstants.ValidLastName,
            TestConstants.ValidBirthDate,
            TestConstants.ValidPhoneNumber,
            emailVerified: false,
            phoneNumberVerified: false);

        // Assert
        userIdentity.Should().NotBeNull();
        userIdentity.Id.Should().NotBeEmpty();
        userIdentity.UserId.Should().Be(userId);
        userIdentity.IdpId.Should().Be(idpId);
        userIdentity.Issuer.Should().Be(issuer);
        userIdentity.Subject.Value.Should().Be(TestConstants.ValidSubject);
        userIdentity.Email.Value.Should().Be(TestConstants.ValidEmail);
        userIdentity.FirstName.Should().Be(TestConstants.ValidFirstName);
        userIdentity.LastName.Should().Be(TestConstants.ValidLastName);
        userIdentity.BirthDate.Should().Be(TestConstants.ValidBirthDate);
        userIdentity.PhoneNumber.Should().Be(TestConstants.ValidPhoneNumber);
        userIdentity.EmailVerified.Should().BeFalse();
        userIdentity.PhoneNumberVerified.Should().BeFalse();
        userIdentity.LastSyncedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void UpdateFromIdp_UpdatesAllFields()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder().Build();
        var newEmail = EmailAddress.Create("newemail@example.com");
        var newFirstName = "Jane";
        var newLastName = "Smith";
        var newPhoneNumber = "+61498765432";

        // Act
        userIdentity.UpdateFromIdp(
            newEmail,
            newFirstName,
            newLastName,
            newPhoneNumber,
            emailVerified: true,
            phoneNumberVerified: true);

        // Assert
        userIdentity.Email.Value.Should().Be("newemail@example.com");
        userIdentity.FirstName.Should().Be(newFirstName);
        userIdentity.LastName.Should().Be(newLastName);
        userIdentity.PhoneNumber.Should().Be(newPhoneNumber);
        userIdentity.EmailVerified.Should().BeTrue();
        userIdentity.PhoneNumberVerified.Should().BeTrue();
        userIdentity.LastSyncedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void UpdateFromIdp_WithNullPhoneNumber_SetsEmptyString()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithPhoneNumber("+61412345678")
            .Build();

        // Act
        userIdentity.UpdateFromIdp(
            EmailAddress.Create("test@example.com"),
            "First",
            "Last",
            phoneNumber: null,
            emailVerified: false,
            phoneNumberVerified: false);

        // Assert
        userIdentity.PhoneNumber.Should().BeEmpty();
    }

    [Fact]
    public void UpdateProfile_PartialUpdate_OnlyUpdatesProvidedFields()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithFirstName("John")
            .WithLastName("Doe")
            .WithPhoneNumber("+61412345678")
            .Build();

        // Act - only update first name
        userIdentity.UpdateProfile(firstName: "Jane");

        // Assert
        userIdentity.FirstName.Should().Be("Jane");
        userIdentity.LastName.Should().Be("Doe");
        userIdentity.PhoneNumber.Should().Be("+61412345678");
    }

    [Fact]
    public void UpdateProfile_AllFieldsNull_DoesNotUpdateAnything()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithFirstName("John")
            .WithLastName("Doe")
            .WithPhoneNumber("+61412345678")
            .Build();

        // Act
        userIdentity.UpdateProfile();

        // Assert
        userIdentity.FirstName.Should().Be("John");
        userIdentity.LastName.Should().Be("Doe");
        userIdentity.PhoneNumber.Should().Be("+61412345678");
    }

    [Fact]
    public void UpdateProfile_UpdateAllFields_UpdatesAllProvided()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder().Build();

        // Act
        userIdentity.UpdateProfile(
            firstName: "Updated",
            lastName: "Name",
            phoneNumber: "+61499999999");

        // Assert
        userIdentity.FirstName.Should().Be("Updated");
        userIdentity.LastName.Should().Be("Name");
        userIdentity.PhoneNumber.Should().Be("+61499999999");
    }

    [Fact]
    public void Builder_CreatesUserIdentityWithDefaults()
    {
        // Act
        var userIdentity = new UserIdentityBuilder().Build();

        // Assert
        userIdentity.Should().NotBeNull();
        userIdentity.Issuer.Should().Be(TestConstants.IFXCognitoIssuer);
        userIdentity.Subject.Value.Should().Be(TestConstants.ValidSubject);
        userIdentity.Email.Value.Should().Be(TestConstants.ValidEmail);
    }

    [Fact]
    public void Builder_WithCustomValues_CreatesCorrectUserIdentity()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var customEmail = "custom@domain.com";

        // Act
        var userIdentity = new UserIdentityBuilder()
            .WithUserId(userId)
            .WithEmail(customEmail)
            .EmailVerified()
            .Build();

        // Assert
        userIdentity.UserId.Should().Be(userId);
        userIdentity.Email.Value.Should().Be(customEmail);
        userIdentity.EmailVerified.Should().BeTrue();
    }
}

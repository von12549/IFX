using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common;

namespace IFX.Modules.Auth.Domain.Tests.ValueObjects;

public class EmailAddressTests
{
    [Theory]
    [InlineData("test@example.com")]
    [InlineData("user.name@domain.co.uk")]
    [InlineData("user+tag@example.org")]
    public void Create_WithValidEmail_ReturnsEmailAddress(string email)
    {
        // Act
        var result = EmailAddress.Create(email);

        // Assert
        result.Should().NotBeNull();
        result.Value.Should().Be(email.ToLowerInvariant());
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Create_WithEmptyEmail_ThrowsArgumentException(string? email)
    {
        // Act
        var act = () => EmailAddress.Create(email!);

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*cannot be empty*");
    }

    [Theory]
    [InlineData("invalid")]
    [InlineData("@domain.com")]
    [InlineData("user@")]
    [InlineData("user@domain")]
    [InlineData("user name@domain.com")]
    public void Create_WithInvalidFormat_ThrowsArgumentException(string email)
    {
        // Act
        var act = () => EmailAddress.Create(email);

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Invalid email address format*");
    }

    [Fact]
    public void Create_NormalizesToLowerCase()
    {
        // Arrange
        var email = "Test.User@Example.COM";

        // Act
        var result = EmailAddress.Create(email);

        // Assert
        result.Value.Should().Be("test.user@example.com");
    }

    [Fact]
    public void Equals_SameEmail_ReturnsTrue()
    {
        // Arrange
        var email1 = EmailAddress.Create("test@example.com");
        var email2 = EmailAddress.Create("TEST@EXAMPLE.COM");

        // Act & Assert
        email1.Equals(email2).Should().BeTrue();
        (email1 == email2).Should().BeTrue();
        (email1 != email2).Should().BeFalse();
    }

    [Fact]
    public void Equals_DifferentEmail_ReturnsFalse()
    {
        // Arrange
        var email1 = EmailAddress.Create("user1@example.com");
        var email2 = EmailAddress.Create("user2@example.com");

        // Act & Assert
        email1.Equals(email2).Should().BeFalse();
        (email1 == email2).Should().BeFalse();
        (email1 != email2).Should().BeTrue();
    }

    [Fact]
    public void Equals_WithNull_ReturnsFalse()
    {
        // Arrange
        var email = EmailAddress.Create("test@example.com");

        // Act & Assert
        email.Equals(null).Should().BeFalse();
        (email == null).Should().BeFalse();
        (null == email).Should().BeFalse();
    }

    [Fact]
    public void GetHashCode_SameEmail_ReturnsSameHashCode()
    {
        // Arrange
        var email1 = EmailAddress.Create("test@example.com");
        var email2 = EmailAddress.Create("test@example.com");

        // Act & Assert
        email1.GetHashCode().Should().Be(email2.GetHashCode());
    }

    [Fact]
    public void ToString_ReturnsEmailValue()
    {
        // Arrange
        var email = EmailAddress.Create("test@example.com");

        // Act & Assert
        email.ToString().Should().Be("test@example.com");
    }
}

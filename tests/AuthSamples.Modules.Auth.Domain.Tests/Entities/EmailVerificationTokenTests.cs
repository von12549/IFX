using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Tests.Entities;

public class EmailVerificationTokenTests
{
    private static readonly Guid TestUserIdentityId = Guid.NewGuid();
    private const string TestEmail = "test@example.com";
    private const string TestTokenHash = "abc123hash";
    private const string TestCode = "123456";

    [Fact]
    public void Create_WithValidParameters_ReturnsToken()
    {
        // Arrange
        var validityPeriod = TimeSpan.FromMinutes(60);

        // Act
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            validityPeriod);

        // Assert
        token.Should().NotBeNull();
        token.Id.Should().NotBeEmpty();
        token.UserIdentityId.Should().Be(TestUserIdentityId);
        token.Email.Should().Be(TestEmail);
        token.TokenHash.Should().Be(TestTokenHash);
        token.Code.Should().Be(TestCode);
        token.IsUsed.Should().BeFalse();
        token.UsedAt.Should().BeNull();
        token.ExpiresAt.Should().BeCloseTo(DateTime.UtcNow.Add(validityPeriod), TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void IsValid_WhenNotUsedAndNotExpired_ReturnsTrue()
    {
        // Arrange
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            TimeSpan.FromMinutes(60));

        // Act
        var isValid = token.IsValid();

        // Assert
        isValid.Should().BeTrue();
    }

    [Fact]
    public void IsValid_WhenUsed_ReturnsFalse()
    {
        // Arrange
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            TimeSpan.FromMinutes(60));

        token.MarkAsUsed();

        // Act
        var isValid = token.IsValid();

        // Assert
        isValid.Should().BeFalse();
    }

    [Fact]
    public void IsValid_WhenExpired_ReturnsFalse()
    {
        // Arrange - create token with negative validity (already expired)
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            TimeSpan.FromMinutes(-1));

        // Act
        var isValid = token.IsValid();

        // Assert
        isValid.Should().BeFalse();
    }

    [Fact]
    public void MarkAsUsed_SetsIsUsedAndUsedAt()
    {
        // Arrange
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            TimeSpan.FromMinutes(60));

        // Act
        token.MarkAsUsed();

        // Assert
        token.IsUsed.Should().BeTrue();
        token.UsedAt.Should().NotBeNull();
        token.UsedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void Invalidate_SetsIsUsedAndUsedAt()
    {
        // Arrange
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            TimeSpan.FromMinutes(60));

        // Act
        token.Invalidate();

        // Assert
        token.IsUsed.Should().BeTrue();
        token.UsedAt.Should().NotBeNull();
        token.UsedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void IsValid_WhenUsedAndExpired_ReturnsFalse()
    {
        // Arrange
        var token = EmailVerificationToken.Create(
            TestUserIdentityId,
            TestEmail,
            TestTokenHash,
            TestCode,
            TimeSpan.FromMinutes(-1));

        token.MarkAsUsed();

        // Act
        var isValid = token.IsValid();

        // Assert
        isValid.Should().BeFalse();
    }

    [Fact]
    public void Create_SetsExpiresAtBasedOnValidityPeriod()
    {
        // Arrange
        var shortValidity = TimeSpan.FromMinutes(5);
        var longValidity = TimeSpan.FromHours(24);

        // Act
        var shortToken = EmailVerificationToken.Create(
            TestUserIdentityId, TestEmail, "hash1", "111111", shortValidity);
        var longToken = EmailVerificationToken.Create(
            TestUserIdentityId, TestEmail, "hash2", "222222", longValidity);

        // Assert
        shortToken.ExpiresAt.Should().BeCloseTo(DateTime.UtcNow.AddMinutes(5), TimeSpan.FromSeconds(1));
        longToken.ExpiresAt.Should().BeCloseTo(DateTime.UtcNow.AddHours(24), TimeSpan.FromSeconds(1));
    }
}

using IFX.Modules.IAM.Domain.Identity;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;

namespace IFX.Modules.IAM.Domain.Tests.Entities;

public class LoginEventTests
{
    [Fact]
    public void CreateSuccess_WithValidParameters_ReturnsLoginEvent()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var ipAddress = TestConstants.ValidIpAddress;
        var userAgent = TestConstants.ValidUserAgent;

        // Act
        var loginEvent = LoginEvent.CreateSuccess(userId, ipAddress, userAgent);

        // Assert
        loginEvent.Should().NotBeNull();
        loginEvent.Id.Should().NotBeEmpty();
        loginEvent.UserId.Should().Be(userId);
        loginEvent.IpAddress.Should().Be(ipAddress);
        loginEvent.UserAgent.Should().Be(userAgent);
        loginEvent.Success.Should().BeTrue();
        loginEvent.FailureReason.Should().BeNull();
        loginEvent.LoginTimestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        loginEvent.DeviceInfo.Should().NotBeNull();
    }

    [Fact]
    public void PublicShape_DoesNotExposePersistedCredentialFields()
    {
        typeof(LoginEvent).GetProperties().Select(property => property.Name).Should().NotContain(
            ["CognitoSessionId", "AccessToken", "RefreshToken", "TokenExpiresAt"]);
    }

    [Fact]
    public void CreateFailure_SetsFailureReason()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var failureReason = "Invalid credentials";

        // Act
        var loginEvent = LoginEvent.CreateFailure(
            userId,
            TestConstants.ValidIpAddress,
            TestConstants.ValidUserAgent,
            failureReason);

        // Assert
        loginEvent.Should().NotBeNull();
        loginEvent.Success.Should().BeFalse();
        loginEvent.FailureReason.Should().Be(failureReason);
    }

    [Fact]
    public void CreateFailure_ParsesDeviceInfo()
    {
        // Arrange
        var userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0";

        // Act
        var loginEvent = LoginEvent.CreateFailure(
            Guid.NewGuid(),
            TestConstants.ValidIpAddress,
            userAgent,
            "Failed");

        // Assert
        loginEvent.DeviceInfo.Should().NotBeNull();
        loginEvent.DeviceInfo.Browser.Should().Be("Chrome");
        loginEvent.DeviceInfo.OS.Should().Be("Windows");
        loginEvent.DeviceInfo.DeviceType.Should().Be("Desktop");
    }

    [Fact]
    public void Builder_AsSuccess_CreatesSuccessfulLoginEvent()
    {
        // Act
        var loginEvent = new LoginEventBuilder()
            .AsSuccess()
            .Build();

        // Assert
        loginEvent.Success.Should().BeTrue();
        loginEvent.FailureReason.Should().BeNull();
    }

    [Fact]
    public void Builder_AsFailure_CreatesFailedLoginEvent()
    {
        // Arrange
        var reason = "Account locked";

        // Act
        var loginEvent = new LoginEventBuilder()
            .AsFailure(reason)
            .Build();

        // Assert
        loginEvent.Success.Should().BeFalse();
        loginEvent.FailureReason.Should().Be(reason);
    }

    [Fact]
    public void Builder_WithCustomUserAgent_ParsesDeviceInfo()
    {
        // Arrange
        var mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile";

        // Act
        var loginEvent = new LoginEventBuilder()
            .WithUserAgent(mobileUserAgent)
            .Build();

        // Assert
        loginEvent.DeviceInfo.DeviceType.Should().Be("Mobile");
        loginEvent.DeviceInfo.OS.Should().Be("iOS");
    }
}

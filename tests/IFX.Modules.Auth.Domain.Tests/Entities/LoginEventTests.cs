using IFX.Modules.Auth.Domain.Entities;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;

namespace IFX.Modules.Auth.Domain.Tests.Entities;

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
    public void CreateSuccess_WithTokens_StoresTokens()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var accessToken = "access-token-123";
        var refreshToken = "refresh-token-456";
        var expiresAt = DateTime.UtcNow.AddHours(1);

        // Act
        var loginEvent = LoginEvent.CreateSuccess(
            userId,
            TestConstants.ValidIpAddress,
            TestConstants.ValidUserAgent,
            cognitoSessionId: "session-123",
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiresAt: expiresAt);

        // Assert
        loginEvent.CognitoSessionId.Should().Be("session-123");
        loginEvent.AccessToken.Should().Be(accessToken);
        loginEvent.RefreshToken.Should().Be(refreshToken);
        loginEvent.TokenExpiresAt.Should().BeCloseTo(expiresAt, TimeSpan.FromSeconds(1));
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
        loginEvent.AccessToken.Should().BeNull();
        loginEvent.RefreshToken.Should().BeNull();
        loginEvent.TokenExpiresAt.Should().BeNull();
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
    public void Builder_WithTokens_StoresTokens()
    {
        // Arrange
        var accessToken = "access-123";
        var refreshToken = "refresh-456";
        var expiresAt = DateTime.UtcNow.AddHours(1);

        // Act
        var loginEvent = new LoginEventBuilder()
            .AsSuccess()
            .WithTokens(accessToken, refreshToken, expiresAt)
            .Build();

        // Assert
        loginEvent.AccessToken.Should().Be(accessToken);
        loginEvent.RefreshToken.Should().Be(refreshToken);
        loginEvent.TokenExpiresAt.Should().BeCloseTo(expiresAt, TimeSpan.FromSeconds(1));
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

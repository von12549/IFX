using AuthSamples.Modules.Auth.Domain.ValueObjects;
using AuthSamples.Tests.Common;

namespace AuthSamples.Modules.Auth.Domain.Tests.ValueObjects;

public class DeviceInfoTests
{
    [Fact]
    public void Parse_WithValidUserAgent_ReturnsDeviceInfo()
    {
        // Arrange
        var userAgent = TestConstants.ValidUserAgent;

        // Act
        var result = DeviceInfo.Parse(userAgent);

        // Assert
        result.Should().NotBeNull();
        result.Browser.Should().NotBeNullOrEmpty();
        result.OS.Should().NotBeNullOrEmpty();
        result.DeviceType.Should().NotBeNullOrEmpty();
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Parse_WithEmptyUserAgent_ReturnsUnknownDeviceInfo(string? userAgent)
    {
        // Act
        var result = DeviceInfo.Parse(userAgent!);

        // Assert
        result.Browser.Should().Be("Unknown");
        result.OS.Should().Be("Unknown");
        result.DeviceType.Should().Be("Unknown");
        result.IsBot.Should().BeFalse();
    }

    [Theory]
    [InlineData("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36", "Chrome")]
    [InlineData("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0", "Edge")]
    [InlineData("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15", "Safari")]
    [InlineData("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0", "Firefox")]
    public void Parse_DetectsBrowser(string userAgent, string expectedBrowser)
    {
        // Act
        var result = DeviceInfo.Parse(userAgent);

        // Assert
        result.Browser.Should().Be(expectedBrowser);
    }

    [Theory]
    [InlineData("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0", "Windows")]
    [InlineData("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", "macOS")]
    [InlineData("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0", "Linux")]
    [InlineData("Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120.0.0.0", "Android")]
    [InlineData("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", "iOS")]
    public void Parse_DetectsOS(string userAgent, string expectedOS)
    {
        // Act
        var result = DeviceInfo.Parse(userAgent);

        // Assert
        result.OS.Should().Be(expectedOS);
    }

    [Theory]
    [InlineData("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", "Mobile")]
    [InlineData("Mozilla/5.0 (Linux; Android 14; SM-G991B) AppleWebKit/537.36 Mobile", "Mobile")]
    [InlineData("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15", "Tablet")]
    [InlineData("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0", "Desktop")]
    public void Parse_DetectsDeviceType(string userAgent, string expectedDeviceType)
    {
        // Act
        var result = DeviceInfo.Parse(userAgent);

        // Assert
        result.DeviceType.Should().Be(expectedDeviceType);
    }

    [Theory]
    [InlineData("Googlebot/2.1 (+http://www.google.com/bot.html)")]
    [InlineData("Mozilla/5.0 (compatible; Bingbot/2.0; +http://www.bing.com/bingbot.htm)")]
    [InlineData("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")]
    [InlineData("Twitterbot/1.0")]
    [InlineData("AhrefsBot/7.0")]
    [InlineData("YandexBot/3.0 crawler")]
    [InlineData("DuckDuckBot-Https/1.1; (+https://duckduckgo.com/duckduckbot) spider")]
    public void Parse_DetectsBot(string userAgent)
    {
        // Act
        var result = DeviceInfo.Parse(userAgent);

        // Assert
        result.IsBot.Should().BeTrue();
    }

    [Fact]
    public void Parse_RegularUserAgent_NotDetectedAsBot()
    {
        // Arrange
        var userAgent = TestConstants.ValidUserAgent;

        // Act
        var result = DeviceInfo.Parse(userAgent);

        // Assert
        result.IsBot.Should().BeFalse();
    }
}

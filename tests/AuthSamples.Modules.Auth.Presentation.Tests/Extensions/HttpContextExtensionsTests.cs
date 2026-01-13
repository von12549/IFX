using System.Net;
using AuthSamples.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Http;

namespace AuthSamples.Modules.Auth.Presentation.Tests.Extensions;

public class HttpContextExtensionsTests
{
    [Fact]
    public void GetIpAddress_WithValidRemoteIpAddress_ReturnsIpAddress()
    {
        // Arrange
        var httpContext = new DefaultHttpContext();
        httpContext.Connection.RemoteIpAddress = IPAddress.Parse("192.168.1.100");

        // Act
        var result = httpContext.GetIpAddress();

        // Assert
        result.Should().Be("192.168.1.100");
    }

    [Fact]
    public void GetIpAddress_WithIPv6Address_ReturnsIpAddress()
    {
        // Arrange
        var httpContext = new DefaultHttpContext();
        httpContext.Connection.RemoteIpAddress = IPAddress.Parse("::1");

        // Act
        var result = httpContext.GetIpAddress();

        // Assert
        result.Should().Be("::1");
    }

    [Fact]
    public void GetIpAddress_WithLoopbackAddress_ReturnsIpAddress()
    {
        // Arrange
        var httpContext = new DefaultHttpContext();
        httpContext.Connection.RemoteIpAddress = IPAddress.Loopback;

        // Act
        var result = httpContext.GetIpAddress();

        // Assert
        result.Should().Be("127.0.0.1");
    }

    [Fact]
    public void GetIpAddress_WithNullRemoteIpAddress_ReturnsUnknown()
    {
        // Arrange
        var httpContext = new DefaultHttpContext();
        // RemoteIpAddress is null by default

        // Act
        var result = httpContext.GetIpAddress();

        // Assert
        result.Should().Be("Unknown");
    }
}

using System.Security.Claims;
using IFX.Modules.Auth.Presentation.Extensions;
using IFX.Tests.Common;

namespace IFX.Modules.Auth.Presentation.Tests.Extensions;

public class ClaimsPrincipalExtensionsTests
{
    [Fact]
    public void GetIssuerAndSubject_WithValidClaims_ReturnsTuple()
    {
        // Arrange
        var claims = new[]
        {
            new Claim("sub", TestConstants.ValidSubject),
            new Claim("iss", TestConstants.IFXCognitoIssuer)
        };
        var identity = new ClaimsIdentity(claims, "Bearer");
        var principal = new ClaimsPrincipal(identity);

        // Act
        var (issuer, subject) = principal.GetIssuerAndSubject();

        // Assert
        issuer.Should().Be(TestConstants.IFXCognitoIssuer);
        subject.Should().Be(TestConstants.ValidSubject);
    }

    [Fact]
    public void GetIssuerAndSubject_WithMissingSubject_ReturnsNullSubject()
    {
        // Arrange
        var claims = new[]
        {
            new Claim("iss", TestConstants.IFXCognitoIssuer)
        };
        var identity = new ClaimsIdentity(claims, "Bearer");
        var principal = new ClaimsPrincipal(identity);

        // Act
        var (issuer, subject) = principal.GetIssuerAndSubject();

        // Assert
        issuer.Should().Be(TestConstants.IFXCognitoIssuer);
        subject.Should().BeNull();
    }

    [Fact]
    public void GetIssuerAndSubject_WithMissingIssuer_ReturnsNullIssuer()
    {
        // Arrange
        var claims = new[]
        {
            new Claim("sub", TestConstants.ValidSubject)
        };
        var identity = new ClaimsIdentity(claims, "Bearer");
        var principal = new ClaimsPrincipal(identity);

        // Act
        var (issuer, subject) = principal.GetIssuerAndSubject();

        // Assert
        issuer.Should().BeNull();
        subject.Should().Be(TestConstants.ValidSubject);
    }

    [Fact]
    public void GetIssuerAndSubject_WithNoClaims_ReturnsNulls()
    {
        // Arrange
        var identity = new ClaimsIdentity();
        var principal = new ClaimsPrincipal(identity);

        // Act
        var (issuer, subject) = principal.GetIssuerAndSubject();

        // Assert
        issuer.Should().BeNull();
        subject.Should().BeNull();
    }

    [Fact]
    public void GetIssuerAndSubject_WithEmptyClaimsPrincipal_ReturnsNulls()
    {
        // Arrange
        var principal = new ClaimsPrincipal();

        // Act
        var (issuer, subject) = principal.GetIssuerAndSubject();

        // Assert
        issuer.Should().BeNull();
        subject.Should().BeNull();
    }

    [Fact]
    public void GetIssuerAndSubject_WithMultipleIdentities_ReturnsFirstClaims()
    {
        // Arrange
        var claims1 = new[]
        {
            new Claim("sub", "subject1"),
            new Claim("iss", "issuer1")
        };
        var claims2 = new[]
        {
            new Claim("sub", "subject2"),
            new Claim("iss", "issuer2")
        };
        var identity1 = new ClaimsIdentity(claims1, "Bearer");
        var identity2 = new ClaimsIdentity(claims2, "Bearer");
        var principal = new ClaimsPrincipal(new[] { identity1, identity2 });

        // Act
        var (issuer, subject) = principal.GetIssuerAndSubject();

        // Assert
        issuer.Should().Be("issuer1");
        subject.Should().Be("subject1");
    }
}

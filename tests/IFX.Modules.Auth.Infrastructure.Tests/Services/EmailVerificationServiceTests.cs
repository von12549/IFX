using IFX.Modules.Auth.Infrastructure.Users.Services;
using System.Text.RegularExpressions;

namespace IFX.Modules.Auth.Infrastructure.Tests.Services;

public class EmailVerificationServiceTests
{
    private readonly EmailVerificationService _service;

    public EmailVerificationServiceTests()
    {
        _service = new EmailVerificationService();
    }

    [Fact]
    public void GenerateVerificationCredentials_ReturnsToken()
    {
        // Act
        var (token, tokenHash, code) = _service.GenerateVerificationCredentials();

        // Assert
        token.Should().NotBeNullOrEmpty();
        tokenHash.Should().NotBeNullOrEmpty();
        code.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public void GenerateVerificationCredentials_TokenIsValidGuidWithoutDashes()
    {
        // Act
        var (token, _, _) = _service.GenerateVerificationCredentials();

        // Assert
        token.Should().HaveLength(32); // GUID without dashes
        token.Should().MatchRegex("^[a-f0-9]{32}$");
    }

    [Fact]
    public void GenerateVerificationCredentials_TokenHashIsSha256()
    {
        // Act
        var (_, tokenHash, _) = _service.GenerateVerificationCredentials();

        // Assert
        tokenHash.Should().HaveLength(64); // SHA256 produces 64 hex chars
        tokenHash.Should().MatchRegex("^[a-f0-9]{64}$");
    }

    [Fact]
    public void GenerateVerificationCredentials_CodeIsSixDigits()
    {
        // Act
        var (_, _, code) = _service.GenerateVerificationCredentials();

        // Assert
        code.Should().HaveLength(6);
        code.Should().MatchRegex("^[0-9]{6}$");
    }

    [Fact]
    public void GenerateVerificationCredentials_TokenHashMatchesToken()
    {
        // Act
        var (token, tokenHash, _) = _service.GenerateVerificationCredentials();

        // Assert
        var computedHash = _service.HashToken(token);
        computedHash.Should().Be(tokenHash);
    }

    [Fact]
    public void GenerateVerificationCredentials_GeneratesUniqueTokensEachCall()
    {
        // Act
        var credentials1 = _service.GenerateVerificationCredentials();
        var credentials2 = _service.GenerateVerificationCredentials();

        // Assert
        credentials1.Token.Should().NotBe(credentials2.Token);
        credentials1.TokenHash.Should().NotBe(credentials2.TokenHash);
    }

    [Fact]
    public void HashToken_ProducesConsistentHash()
    {
        // Arrange
        var token = "test-token-12345";

        // Act
        var hash1 = _service.HashToken(token);
        var hash2 = _service.HashToken(token);

        // Assert
        hash1.Should().Be(hash2);
    }

    [Fact]
    public void HashToken_ProducesDifferentHashesForDifferentTokens()
    {
        // Arrange
        var token1 = "token-1";
        var token2 = "token-2";

        // Act
        var hash1 = _service.HashToken(token1);
        var hash2 = _service.HashToken(token2);

        // Assert
        hash1.Should().NotBe(hash2);
    }

    [Fact]
    public void HashToken_ProducesLowercaseHex()
    {
        // Arrange
        var token = "TEST-TOKEN";

        // Act
        var hash = _service.HashToken(token);

        // Assert
        hash.Should().MatchRegex("^[a-f0-9]+$"); // Only lowercase hex chars
        hash.Should().NotMatchRegex("[A-F]"); // No uppercase
    }

    [Fact]
    public void GenerateVerificationCode_ReturnsSixDigitCode()
    {
        // Act
        var code = _service.GenerateVerificationCode();

        // Assert
        code.Should().HaveLength(6);
        int.TryParse(code, out _).Should().BeTrue();
    }

    [Fact]
    public void GenerateVerificationCode_PadsWithZeros()
    {
        // The code should always be 6 digits, even if the number is small
        // We can't easily test this deterministically, but we can verify format
        var codes = new List<string>();
        for (int i = 0; i < 100; i++)
        {
            codes.Add(_service.GenerateVerificationCode());
        }

        // Assert all codes are 6 digits
        codes.Should().OnlyContain(c => c.Length == 6);
        codes.Should().OnlyContain(c => Regex.IsMatch(c, "^[0-9]{6}$"));
    }

    [Fact]
    public void BuildVerificationEmailHtml_ContainsRequiredElements()
    {
        // Arrange
        var userName = "John Doe";
        var code = "123456";
        var verificationLink = "https://example.com/verify?token=abc";
        var expiryMinutes = 60;

        // Act
        var html = _service.BuildVerificationEmailHtml(userName, code, verificationLink, expiryMinutes);

        // Assert
        html.Should().Contain(userName);
        html.Should().Contain(code);
        html.Should().Contain(verificationLink);
        html.Should().Contain("60");
        html.Should().Contain("<!DOCTYPE html>");
        html.Should().Contain("Verify Your Email");
    }

    [Fact]
    public void BuildVerificationEmailHtml_EscapesHtmlCharacters()
    {
        // Arrange
        var userName = "<script>alert('xss')</script>";
        var code = "123456";
        var verificationLink = "https://example.com/verify?a=1&b=2";
        var expiryMinutes = 60;

        // Act
        var html = _service.BuildVerificationEmailHtml(userName, code, verificationLink, expiryMinutes);

        // Assert
        html.Should().NotContain("<script>");
        html.Should().Contain("&lt;script&gt;");
        html.Should().Contain("&amp;"); // The & in the link should be escaped
    }

    [Fact]
    public void BuildVerificationEmailPlainText_ContainsRequiredElements()
    {
        // Arrange
        var userName = "John Doe";
        var code = "123456";
        var verificationLink = "https://example.com/verify?token=abc";
        var expiryMinutes = 60;

        // Act
        var plainText = _service.BuildVerificationEmailPlainText(userName, code, verificationLink, expiryMinutes);

        // Assert
        plainText.Should().Contain(userName);
        plainText.Should().Contain(code);
        plainText.Should().Contain(verificationLink);
        plainText.Should().Contain("60");
        plainText.Should().Contain("Verify Your Email");
    }

    [Fact]
    public void BuildVerificationEmailPlainText_DoesNotContainHtmlTags()
    {
        // Arrange
        var userName = "John Doe";
        var code = "123456";
        var verificationLink = "https://example.com/verify";
        var expiryMinutes = 60;

        // Act
        var plainText = _service.BuildVerificationEmailPlainText(userName, code, verificationLink, expiryMinutes);

        // Assert
        plainText.Should().NotMatchRegex("<[^>]+>");
    }
}

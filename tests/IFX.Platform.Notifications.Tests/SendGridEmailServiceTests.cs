using System.Net;
using IFX.Platform.Notifications.Abstractions.Models;
using IFX.Platform.Notifications.Infrastructure.SendGrid;
using Microsoft.Extensions.Logging;
using Moq;
using SendGrid;
using SendGrid.Helpers.Mail;

namespace IFX.Platform.Notifications.Tests;

public class SendGridEmailServiceTests
{
    private readonly Mock<ISendGridClient> _mockClient;
    private readonly Mock<ILogger<SendGridEmailService>> _mockLogger;
    private readonly SendGridSettings _settings;
    private readonly SendGridEmailService _sut;

    public SendGridEmailServiceTests()
    {
        _mockClient = new Mock<ISendGridClient>();
        _mockLogger = new Mock<ILogger<SendGridEmailService>>();
        _settings = new SendGridSettings
        {
            ApiKey = "test-api-key",
            DefaultFromEmail = "default@example.com",
            DefaultFromName = "Default Sender"
        };
        _sut = new SendGridEmailService(_mockClient.Object, _settings, _mockLogger.Object);
    }

    #region SendEmailAsync Tests

    [Fact]
    public async Task SendEmailAsync_WhenSuccessful_ReturnsSuccess()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            HtmlBody = "<p>Test Body</p>"
        };

        var response = CreateMockResponse(HttpStatusCode.Accepted, "msg-123");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);

        // Act
        var result = await _sut.SendEmailAsync(message);

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal("msg-123", result.MessageId);
        Assert.Null(result.ErrorMessage);
    }

    [Fact]
    public async Task SendEmailAsync_WhenFailed_ReturnsFailure()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            PlainTextBody = "Test Body"
        };

        var response = CreateMockResponse(HttpStatusCode.BadRequest, null, "Invalid email address");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);

        // Act
        var result = await _sut.SendEmailAsync(message);

        // Assert
        Assert.False(result.IsSuccess);
        Assert.Null(result.MessageId);
        Assert.Contains("BadRequest", result.ErrorMessage);
    }

    [Fact]
    public async Task SendEmailAsync_WhenExceptionThrown_ReturnsFailure()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            HtmlBody = "<p>Test</p>"
        };

        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Network error"));

        // Act
        var result = await _sut.SendEmailAsync(message);

        // Assert
        Assert.False(result.IsSuccess);
        Assert.Equal("Network error", result.ErrorMessage);
    }

    [Fact]
    public async Task SendEmailAsync_UsesDefaultFromWhenNotSpecified()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            HtmlBody = "<p>Test</p>"
        };

        SendGridMessage? capturedMessage = null;
        var response = CreateMockResponse(HttpStatusCode.Accepted, "msg-456");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .Callback<SendGridMessage, CancellationToken>((msg, _) => capturedMessage = msg)
            .ReturnsAsync(response);

        // Act
        await _sut.SendEmailAsync(message);

        // Assert
        Assert.NotNull(capturedMessage);
        Assert.Equal(_settings.DefaultFromEmail, capturedMessage.From.Email);
        Assert.Equal(_settings.DefaultFromName, capturedMessage.From.Name);
    }

    [Fact]
    public async Task SendEmailAsync_UsesCustomFromWhenSpecified()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            HtmlBody = "<p>Test</p>",
            From = "custom@example.com",
            FromName = "Custom Sender"
        };

        SendGridMessage? capturedMessage = null;
        var response = CreateMockResponse(HttpStatusCode.Accepted, "msg-789");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .Callback<SendGridMessage, CancellationToken>((msg, _) => capturedMessage = msg)
            .ReturnsAsync(response);

        // Act
        await _sut.SendEmailAsync(message);

        // Assert
        Assert.NotNull(capturedMessage);
        Assert.Equal("custom@example.com", capturedMessage.From.Email);
        Assert.Equal("Custom Sender", capturedMessage.From.Name);
    }

    [Fact]
    public async Task SendEmailAsync_IncludesCcAndBcc()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            HtmlBody = "<p>Test</p>",
            Cc = new[] { "cc1@example.com", "cc2@example.com" },
            Bcc = new[] { "bcc@example.com" }
        };

        SendGridMessage? capturedMessage = null;
        var response = CreateMockResponse(HttpStatusCode.Accepted, "msg-cc");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .Callback<SendGridMessage, CancellationToken>((msg, _) => capturedMessage = msg)
            .ReturnsAsync(response);

        // Act
        await _sut.SendEmailAsync(message);

        // Assert
        Assert.NotNull(capturedMessage);
        var personalization = capturedMessage.Personalizations.First();
        Assert.Equal(2, personalization.Ccs.Count);
        Assert.Single(personalization.Bccs);
    }

    #endregion

    #region SendTemplatedEmailAsync Tests

    [Fact]
    public async Task SendTemplatedEmailAsync_WhenSuccessful_ReturnsSuccess()
    {
        // Arrange
        var message = new TemplatedEmailMessage
        {
            To = "recipient@example.com",
            TemplateId = "d-template123",
            TemplateData = new Dictionary<string, object>
            {
                { "name", "John" },
                { "code", "12345" }
            }
        };

        var response = CreateMockResponse(HttpStatusCode.Accepted, "msg-template");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);

        // Act
        var result = await _sut.SendTemplatedEmailAsync(message);

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal("msg-template", result.MessageId);
    }

    [Fact]
    public async Task SendTemplatedEmailAsync_SetsTemplateIdCorrectly()
    {
        // Arrange
        var message = new TemplatedEmailMessage
        {
            To = "recipient@example.com",
            TemplateId = "d-mytemplate"
        };

        SendGridMessage? capturedMessage = null;
        var response = CreateMockResponse(HttpStatusCode.Accepted, "msg");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .Callback<SendGridMessage, CancellationToken>((msg, _) => capturedMessage = msg)
            .ReturnsAsync(response);

        // Act
        await _sut.SendTemplatedEmailAsync(message);

        // Assert
        Assert.NotNull(capturedMessage);
        Assert.Equal("d-mytemplate", capturedMessage.TemplateId);
    }

    #endregion

    #region SendBatchAsync Tests

    [Fact]
    public async Task SendBatchAsync_SendsAllMessages()
    {
        // Arrange
        var messages = new[]
        {
            new EmailMessage { To = "user1@example.com", Subject = "Test 1", PlainTextBody = "Body 1" },
            new EmailMessage { To = "user2@example.com", Subject = "Test 2", PlainTextBody = "Body 2" },
            new EmailMessage { To = "user3@example.com", Subject = "Test 3", PlainTextBody = "Body 3" }
        };

        var response = CreateMockResponse(HttpStatusCode.Accepted, "batch-msg");
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);

        // Act
        var results = await _sut.SendBatchAsync(messages);

        // Assert
        Assert.Equal(3, results.Count);
        Assert.All(results, r => Assert.True(r.IsSuccess));
        _mockClient.Verify(
            x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()),
            Times.Exactly(3));
    }

    [Fact]
    public async Task SendBatchAsync_ReturnsIndividualResults()
    {
        // Arrange
        var messages = new[]
        {
            new EmailMessage { To = "success@example.com", Subject = "Test 1", PlainTextBody = "Body 1" },
            new EmailMessage { To = "fail@example.com", Subject = "Test 2", PlainTextBody = "Body 2" }
        };

        var successResponse = CreateMockResponse(HttpStatusCode.Accepted, "msg-1");
        var failResponse = CreateMockResponse(HttpStatusCode.BadRequest, null, "Error");

        var callCount = 0;
        _mockClient
            .Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(() => ++callCount == 1 ? successResponse : failResponse);

        // Act
        var results = await _sut.SendBatchAsync(messages);

        // Assert
        Assert.Equal(2, results.Count);
        Assert.True(results[0].IsSuccess);
        Assert.False(results[1].IsSuccess);
    }

    #endregion

    #region Helper Methods

    private static Response CreateMockResponse(HttpStatusCode statusCode, string? messageId, string? body = null)
    {
        var httpResponse = new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(body ?? "")
        };

        if (messageId != null)
        {
            httpResponse.Headers.Add("X-Message-Id", messageId);
        }

        return new Response(statusCode, httpResponse.Content, httpResponse.Headers);
    }

    #endregion
}

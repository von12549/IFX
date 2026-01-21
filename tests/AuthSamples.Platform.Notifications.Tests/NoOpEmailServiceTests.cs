using AuthSamples.Platform.Notifications.Abstractions.Models;
using AuthSamples.Platform.Notifications.Composition;
using Microsoft.Extensions.Logging;
using Moq;

namespace AuthSamples.Platform.Notifications.Tests;

public class NoOpEmailServiceTests
{
    private readonly Mock<ILogger<NoOpEmailService>> _mockLogger;
    private readonly NoOpEmailService _sut;

    public NoOpEmailServiceTests()
    {
        _mockLogger = new Mock<ILogger<NoOpEmailService>>();
        _sut = new NoOpEmailService(_mockLogger.Object);
    }

    #region SendEmailAsync Tests

    [Fact]
    public async Task SendEmailAsync_AlwaysReturnsSuccess()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "recipient@example.com",
            Subject = "Test Subject",
            HtmlBody = "<p>Test Body</p>"
        };

        // Act
        var result = await _sut.SendEmailAsync(message);

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal("noop-message-id", result.MessageId);
        Assert.Null(result.ErrorMessage);
    }

    [Fact]
    public async Task SendEmailAsync_LogsMessageDetails()
    {
        // Arrange
        var message = new EmailMessage
        {
            To = "test@example.com",
            Subject = "Important Subject",
            PlainTextBody = "Body content"
        };

        // Act
        await _sut.SendEmailAsync(message);

        // Assert
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("test@example.com") && v.ToString()!.Contains("Important Subject")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region SendTemplatedEmailAsync Tests

    [Fact]
    public async Task SendTemplatedEmailAsync_AlwaysReturnsSuccess()
    {
        // Arrange
        var message = new TemplatedEmailMessage
        {
            To = "recipient@example.com",
            TemplateId = "d-template123",
            TemplateData = new Dictionary<string, object> { { "name", "John" } }
        };

        // Act
        var result = await _sut.SendTemplatedEmailAsync(message);

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal("noop-message-id", result.MessageId);
        Assert.Null(result.ErrorMessage);
    }

    [Fact]
    public async Task SendTemplatedEmailAsync_LogsTemplateDetails()
    {
        // Arrange
        var message = new TemplatedEmailMessage
        {
            To = "user@example.com",
            TemplateId = "d-welcome-template"
        };

        // Act
        await _sut.SendTemplatedEmailAsync(message);

        // Assert
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("user@example.com") && v.ToString()!.Contains("d-welcome-template")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region SendBatchAsync Tests

    [Fact]
    public async Task SendBatchAsync_ReturnsSuccessForAllMessages()
    {
        // Arrange
        var messages = new[]
        {
            new EmailMessage { To = "user1@example.com", Subject = "Test 1", PlainTextBody = "Body 1" },
            new EmailMessage { To = "user2@example.com", Subject = "Test 2", PlainTextBody = "Body 2" },
            new EmailMessage { To = "user3@example.com", Subject = "Test 3", PlainTextBody = "Body 3" }
        };

        // Act
        var results = await _sut.SendBatchAsync(messages);

        // Assert
        Assert.Equal(3, results.Count);
        Assert.All(results, r =>
        {
            Assert.True(r.IsSuccess);
            Assert.Equal("noop-message-id", r.MessageId);
        });
    }

    [Fact]
    public async Task SendBatchAsync_LogsEachMessage()
    {
        // Arrange
        var messages = new[]
        {
            new EmailMessage { To = "batch1@example.com", Subject = "Subject 1", PlainTextBody = "Body" },
            new EmailMessage { To = "batch2@example.com", Subject = "Subject 2", PlainTextBody = "Body" }
        };

        // Act
        await _sut.SendBatchAsync(messages);

        // Assert
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.IsAny<It.IsAnyType>(),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Exactly(2));
    }

    [Fact]
    public async Task SendBatchAsync_WithEmptyList_ReturnsEmptyResults()
    {
        // Arrange
        var messages = Array.Empty<EmailMessage>();

        // Act
        var results = await _sut.SendBatchAsync(messages);

        // Assert
        Assert.Empty(results);
    }

    #endregion
}

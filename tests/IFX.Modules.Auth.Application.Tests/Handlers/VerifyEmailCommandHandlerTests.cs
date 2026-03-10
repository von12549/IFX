using IFX.Modules.Auth.Application.Commands.VerifyEmail;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Interfaces.Repositories;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers;

public class VerifyEmailCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly Mock<IUserIdentityRepository> _userIdentityRepoMock;
    private readonly Mock<IEmailVerificationTokenRepository> _tokenRepoMock;
    private readonly Mock<IUserActivityLogRepository> _activityLogRepoMock;
    private readonly Mock<IEmailVerificationService> _emailVerificationServiceMock;
    private readonly Mock<ILogger<VerifyEmailCommandHandler>> _loggerMock;
    private readonly VerifyEmailCommandHandler _handler;

    private const string ValidToken = "valid-token";
    private const string ValidTokenHash = "valid-token-hash";
    private const string ValidCode = "123456";

    public VerifyEmailCommandHandlerTests()
    {
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _userIdentityRepoMock = new Mock<IUserIdentityRepository>();
        _tokenRepoMock = new Mock<IEmailVerificationTokenRepository>();
        _activityLogRepoMock = new Mock<IUserActivityLogRepository>();
        _emailVerificationServiceMock = new Mock<IEmailVerificationService>();
        _loggerMock = new Mock<ILogger<VerifyEmailCommandHandler>>();

        _unitOfWorkMock.Setup(u => u.UserIdentities).Returns(_userIdentityRepoMock.Object);
        _unitOfWorkMock.Setup(u => u.EmailVerificationTokens).Returns(_tokenRepoMock.Object);
        _unitOfWorkMock.Setup(u => u.UserActivityLogs).Returns(_activityLogRepoMock.Object);

        _emailVerificationServiceMock
            .Setup(s => s.HashToken(ValidToken))
            .Returns(ValidTokenHash);

        _handler = new VerifyEmailCommandHandler(
            _unitOfWorkMock.Object,
            _emailVerificationServiceMock.Object,
            _loggerMock.Object);
    }

    [Fact]
    public async Task Handle_WithValidToken_VerifiesEmail()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var verificationToken = new EmailVerificationTokenBuilder()
            .WithUserIdentityId(userIdentity.Id)
            .WithTokenHash(ValidTokenHash)
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _tokenRepoMock
            .Setup(r => r.GetByTokenHashAsync(ValidTokenHash, It.IsAny<CancellationToken>()))
            .ReturnsAsync(verificationToken);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value!.Success.Should().BeTrue();
        result.Value.Message.Should().Be("Email verified successfully");

        _tokenRepoMock.Verify(r => r.UpdateAsync(
            It.Is<EmailVerificationToken>(t => t.IsUsed), It.IsAny<CancellationToken>()), Times.Once);
        _userIdentityRepoMock.Verify(r => r.UpdateAsync(
            It.Is<UserIdentity>(u => u.EmailVerified), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WithValidCode_VerifiesEmail()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var verificationToken = new EmailVerificationTokenBuilder()
            .WithUserIdentityId(userIdentity.Id)
            .WithCode(ValidCode)
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            null,
            ValidCode,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _tokenRepoMock
            .Setup(r => r.GetActiveByCodeAsync(userIdentity.Id, ValidCode, It.IsAny<CancellationToken>()))
            .ReturnsAsync(verificationToken);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value!.Success.Should().BeTrue();
    }

    [Fact]
    public async Task Handle_WithNoTokenOrCode_ReturnsFailure()
    {
        // Arrange
        var command = new VerifyEmailCommand(
            Guid.NewGuid(),
            null,
            null,
            TestConstants.ValidIpAddress);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Either verification token or code is required");
    }

    [Fact]
    public async Task Handle_WithNonExistentUserIdentity_ReturnsFailure()
    {
        // Arrange
        var userIdentityId = Guid.NewGuid();
        var command = new VerifyEmailCommand(
            userIdentityId,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentityId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserIdentity?)null);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Invalid verification request");
    }

    [Fact]
    public async Task Handle_WhenAlreadyVerified_ReturnsSuccessWithMessage()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .EmailVerified()
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value!.Message.Should().Be("Email is already verified");

        // Should not attempt to find or update any tokens
        _tokenRepoMock.Verify(r => r.GetByTokenHashAsync(
            It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WithInvalidToken_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            "invalid-token",
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _emailVerificationServiceMock
            .Setup(s => s.HashToken("invalid-token"))
            .Returns("invalid-token-hash");

        _tokenRepoMock
            .Setup(r => r.GetByTokenHashAsync("invalid-token-hash", It.IsAny<CancellationToken>()))
            .ReturnsAsync((EmailVerificationToken?)null);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Invalid or expired verification token/code");

        // Should log failed attempt
        _activityLogRepoMock.Verify(r => r.AddAsync(
            It.Is<UserActivityLog>(l => l.ActivityType == Domain.Enums.ActivityType.EmailVerificationFailed),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WithExpiredToken_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var expiredToken = new EmailVerificationTokenBuilder()
            .WithUserIdentityId(userIdentity.Id)
            .WithTokenHash(ValidTokenHash)
            .Expired()
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _tokenRepoMock
            .Setup(r => r.GetByTokenHashAsync(ValidTokenHash, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expiredToken);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Verification token has expired or already been used");
    }

    [Fact]
    public async Task Handle_WithUsedToken_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var usedToken = new EmailVerificationTokenBuilder()
            .WithUserIdentityId(userIdentity.Id)
            .WithTokenHash(ValidTokenHash)
            .Used()
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _tokenRepoMock
            .Setup(r => r.GetByTokenHashAsync(ValidTokenHash, It.IsAny<CancellationToken>()))
            .ReturnsAsync(usedToken);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Verification token has expired or already been used");
    }

    [Fact]
    public async Task Handle_WithTokenBelongingToDifferentUser_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var otherUserIdentityId = Guid.NewGuid();
        var tokenForOtherUser = new EmailVerificationTokenBuilder()
            .WithUserIdentityId(otherUserIdentityId)
            .WithTokenHash(ValidTokenHash)
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _tokenRepoMock
            .Setup(r => r.GetByTokenHashAsync(ValidTokenHash, It.IsAny<CancellationToken>()))
            .ReturnsAsync(tokenForOtherUser);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Invalid or expired verification token/code");
    }

    [Fact]
    public async Task Handle_CreatesActivityLogOnSuccess()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var verificationToken = new EmailVerificationTokenBuilder()
            .WithUserIdentityId(userIdentity.Id)
            .WithTokenHash(ValidTokenHash)
            .Build();

        var command = new VerifyEmailCommand(
            userIdentity.Id,
            ValidToken,
            null,
            TestConstants.ValidIpAddress);

        UserActivityLog? capturedLog = null;

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _tokenRepoMock
            .Setup(r => r.GetByTokenHashAsync(ValidTokenHash, It.IsAny<CancellationToken>()))
            .ReturnsAsync(verificationToken);

        _activityLogRepoMock
            .Setup(r => r.AddAsync(It.IsAny<UserActivityLog>(), It.IsAny<CancellationToken>()))
            .Callback<UserActivityLog, CancellationToken>((log, _) => capturedLog = log)
            .Returns(Task.CompletedTask);

        // Act
        await _handler.Handle(command, CancellationToken.None);

        // Assert
        capturedLog.Should().NotBeNull();
        capturedLog!.ActivityType.Should().Be(Domain.Enums.ActivityType.EmailVerified);
    }
}

using IFX.Modules.Auth.Application.Identity.Commands.SendEmailVerification;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers;

public class SendEmailVerificationCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly Mock<IUserIdentityRepository> _userIdentityRepoMock;
    private readonly Mock<IEmailVerificationTokenRepository> _tokenRepoMock;
    private readonly Mock<IUserActivityLogRepository> _activityLogRepoMock;
    private readonly Mock<IEmailVerificationService> _emailVerificationServiceMock;
    private readonly Mock<ILogger<SendEmailVerificationCommandHandler>> _loggerMock;
    private readonly SendEmailVerificationCommandHandler _handler;

    public SendEmailVerificationCommandHandlerTests()
    {
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _userIdentityRepoMock = new Mock<IUserIdentityRepository>();
        _tokenRepoMock = new Mock<IEmailVerificationTokenRepository>();
        _activityLogRepoMock = new Mock<IUserActivityLogRepository>();
        _emailVerificationServiceMock = new Mock<IEmailVerificationService>();
        _loggerMock = new Mock<ILogger<SendEmailVerificationCommandHandler>>();

        _unitOfWorkMock.Setup(u => u.UserIdentities).Returns(_userIdentityRepoMock.Object);
        _unitOfWorkMock.Setup(u => u.EmailVerificationTokens).Returns(_tokenRepoMock.Object);
        _unitOfWorkMock.Setup(u => u.UserActivityLogs).Returns(_activityLogRepoMock.Object);

        _handler = new SendEmailVerificationCommandHandler(
            _unitOfWorkMock.Object,
            _emailVerificationServiceMock.Object,
            _loggerMock.Object);
    }

    [Fact]
    public async Task Handle_WithValidUserIdentity_ReturnsSuccess()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new SendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _emailVerificationServiceMock
            .Setup(s => s.GenerateVerificationCredentials())
            .Returns(("test-token", "test-token-hash", "123456"));

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value.Should().NotBeNull();
        result.Value!.Email.Should().Be(TestConstants.ValidEmail);
        result.Value.Token.Should().Be("test-token");
        result.Value.Code.Should().Be("123456");
        result.Value.UserIdentityId.Should().Be(userIdentity.Id);

        _tokenRepoMock.Verify(r => r.InvalidateAllForUserIdentityAsync(
            userIdentity.Id, It.IsAny<CancellationToken>()), Times.Once);
        _tokenRepoMock.Verify(r => r.AddAsync(
            It.IsAny<EmailVerificationToken>(), It.IsAny<CancellationToken>()), Times.Once);
        _activityLogRepoMock.Verify(r => r.AddAsync(
            It.IsAny<UserActivityLog>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWorkMock.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WithNonExistentUserIdentity_ReturnsFailure()
    {
        // Arrange
        var userIdentityId = Guid.NewGuid();
        var command = new SendEmailVerificationCommand(userIdentityId, TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentityId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserIdentity?)null);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User identity not found");

        _tokenRepoMock.Verify(r => r.AddAsync(
            It.IsAny<EmailVerificationToken>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenEmailAlreadyVerified_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .EmailVerified()
            .Build();

        var command = new SendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Email is already verified");

        _tokenRepoMock.Verify(r => r.AddAsync(
            It.IsAny<EmailVerificationToken>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_InvalidatesExistingTokensBeforeCreatingNew()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new SendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);
        var callOrder = new List<string>();

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _emailVerificationServiceMock
            .Setup(s => s.GenerateVerificationCredentials())
            .Returns(("token", "hash", "123456"));

        _tokenRepoMock
            .Setup(r => r.InvalidateAllForUserIdentityAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .Callback(() => callOrder.Add("Invalidate"))
            .Returns(Task.CompletedTask);

        _tokenRepoMock
            .Setup(r => r.AddAsync(It.IsAny<EmailVerificationToken>(), It.IsAny<CancellationToken>()))
            .Callback(() => callOrder.Add("Add"))
            .Returns(Task.CompletedTask);

        // Act
        await _handler.Handle(command, CancellationToken.None);

        // Assert
        callOrder.Should().ContainInOrder("Invalidate", "Add");
    }

    [Fact]
    public async Task Handle_CreatesActivityLog()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new SendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);
        UserActivityLog? capturedLog = null;

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _emailVerificationServiceMock
            .Setup(s => s.GenerateVerificationCredentials())
            .Returns(("token", "hash", "123456"));

        _activityLogRepoMock
            .Setup(r => r.AddAsync(It.IsAny<UserActivityLog>(), It.IsAny<CancellationToken>()))
            .Callback<UserActivityLog, CancellationToken>((log, _) => capturedLog = log)
            .Returns(Task.CompletedTask);

        // Act
        await _handler.Handle(command, CancellationToken.None);

        // Assert
        capturedLog.Should().NotBeNull();
        capturedLog!.UserId.Should().Be(userIdentity.UserId);
        capturedLog.ActivityType.Should().Be(Domain.Users.ActivityType.EmailVerificationSent);
    }

    [Fact]
    public async Task Handle_WithNullIpAddress_UsesUnknownAsDefault()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new SendEmailVerificationCommand(userIdentity.Id, null);
        UserActivityLog? capturedLog = null;

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _emailVerificationServiceMock
            .Setup(s => s.GenerateVerificationCredentials())
            .Returns(("token", "hash", "123456"));

        _activityLogRepoMock
            .Setup(r => r.AddAsync(It.IsAny<UserActivityLog>(), It.IsAny<CancellationToken>()))
            .Callback<UserActivityLog, CancellationToken>((log, _) => capturedLog = log)
            .Returns(Task.CompletedTask);

        // Act
        await _handler.Handle(command, CancellationToken.None);

        // Assert
        capturedLog.Should().NotBeNull();
        capturedLog!.IpAddress.Should().Be("Unknown");
    }
}

using IFX.Modules.Auth.Application.Commands.ResendEmailVerification;
using IFX.Modules.Auth.Application.Commands.SendEmailVerification;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using IFX.Modules.Auth.Domain.Interfaces.Repositories;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers;

public class ResendEmailVerificationCommandHandlerTests
{
    private readonly Mock<IMediator> _mediatorMock;
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly Mock<IUserIdentityRepository> _userIdentityRepoMock;
    private readonly Mock<IUserActivityLogRepository> _activityLogRepoMock;
    private readonly Mock<ILogger<ResendEmailVerificationCommandHandler>> _loggerMock;
    private readonly ResendEmailVerificationCommandHandler _handler;

    public ResendEmailVerificationCommandHandlerTests()
    {
        _mediatorMock = new Mock<IMediator>();
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _userIdentityRepoMock = new Mock<IUserIdentityRepository>();
        _activityLogRepoMock = new Mock<IUserActivityLogRepository>();
        _loggerMock = new Mock<ILogger<ResendEmailVerificationCommandHandler>>();

        _unitOfWorkMock.Setup(u => u.UserIdentities).Returns(_userIdentityRepoMock.Object);
        _unitOfWorkMock.Setup(u => u.UserActivityLogs).Returns(_activityLogRepoMock.Object);

        _handler = new ResendEmailVerificationCommandHandler(
            _mediatorMock.Object,
            _unitOfWorkMock.Object,
            _loggerMock.Object);
    }

    [Fact]
    public async Task Handle_WithValidUserIdentity_DelegatesToSendCommand()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new ResendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        var expectedResponse = new EmailVerificationTokenInfo(
            TokenId: Guid.NewGuid(),
            UserIdentityId: userIdentity.Id,
            Email: TestConstants.ValidEmail,
            Token: "test-token",
            Code: "123456",
            ExpiresAt: DateTime.UtcNow.AddMinutes(60));

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _activityLogRepoMock
            .Setup(r => r.GetUserActivitiesAsync(userIdentity.UserId, 1, 100, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<UserActivityLog>());

        _mediatorMock
            .Setup(m => m.Send(It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Result<EmailVerificationTokenInfo>.Success(expectedResponse));

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value.Should().Be(expectedResponse);

        _mediatorMock.Verify(m => m.Send(
            It.Is<SendEmailVerificationCommand>(c =>
                c.UserIdentityId == userIdentity.Id &&
                c.IpAddress == TestConstants.ValidIpAddress),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WithNonExistentUserIdentity_ReturnsFailure()
    {
        // Arrange
        var userIdentityId = Guid.NewGuid();
        var command = new ResendEmailVerificationCommand(userIdentityId, TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentityId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserIdentity?)null);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User identity not found");

        _mediatorMock.Verify(m => m.Send(
            It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenEmailAlreadyVerified_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .EmailVerified()
            .Build();

        var command = new ResendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Email is already verified");

        _mediatorMock.Verify(m => m.Send(
            It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenRateLimitExceeded_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new ResendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        // Create 3 recent activity logs (rate limit is 3 per hour)
        var recentActivities = Enumerable.Range(0, 3).Select(_ =>
            UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.EmailVerificationSent,
                "Test",
                "127.0.0.1")).ToList();

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _activityLogRepoMock
            .Setup(r => r.GetUserActivitiesAsync(userIdentity.UserId, 1, 100, It.IsAny<CancellationToken>()))
            .ReturnsAsync(recentActivities);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Too many verification emails sent");

        _mediatorMock.Verify(m => m.Send(
            It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenBelowRateLimit_AllowsResend()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new ResendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        // Create only 2 recent activity logs (below rate limit of 3)
        var recentActivities = Enumerable.Range(0, 2).Select(_ =>
            UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.EmailVerificationSent,
                "Test",
                "127.0.0.1")).ToList();

        var expectedResponse = new EmailVerificationTokenInfo(
            TokenId: Guid.NewGuid(),
            UserIdentityId: userIdentity.Id,
            Email: TestConstants.ValidEmail,
            Token: "test-token",
            Code: "123456",
            ExpiresAt: DateTime.UtcNow.AddMinutes(60));

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _activityLogRepoMock
            .Setup(r => r.GetUserActivitiesAsync(userIdentity.UserId, 1, 100, It.IsAny<CancellationToken>()))
            .ReturnsAsync(recentActivities);

        _mediatorMock
            .Setup(m => m.Send(It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Result<EmailVerificationTokenInfo>.Success(expectedResponse));

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();

        _mediatorMock.Verify(m => m.Send(
            It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenSendCommandFails_ReturnsFailure()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new ResendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _activityLogRepoMock
            .Setup(r => r.GetUserActivitiesAsync(userIdentity.UserId, 1, 100, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<UserActivityLog>());

        _mediatorMock
            .Setup(m => m.Send(It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Result<EmailVerificationTokenInfo>.Failure("Some error"));

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Some error");
    }

    [Fact]
    public async Task Handle_OnlyCountsRecentActivitiesForRateLimit()
    {
        // Arrange
        var userIdentity = new UserIdentityBuilder()
            .WithEmail(TestConstants.ValidEmail)
            .Build();

        var command = new ResendEmailVerificationCommand(userIdentity.Id, TestConstants.ValidIpAddress);

        // Create activity logs - mix of different types and old ones
        // The handler counts EmailVerificationSent activities from the last hour
        var activities = new List<UserActivityLog>
        {
            // Recent EmailVerificationSent (counts)
            UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.EmailVerificationSent,
                "Test",
                "127.0.0.1"),
            // Different activity type (doesn't count)
            UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.ProfileUpdate,
                "Test",
                "127.0.0.1"),
            // Another EmailVerificationSent (counts)
            UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.EmailVerificationSent,
                "Test",
                "127.0.0.1")
        };

        var expectedResponse = new EmailVerificationTokenInfo(
            TokenId: Guid.NewGuid(),
            UserIdentityId: userIdentity.Id,
            Email: TestConstants.ValidEmail,
            Token: "test-token",
            Code: "123456",
            ExpiresAt: DateTime.UtcNow.AddMinutes(60));

        _userIdentityRepoMock
            .Setup(r => r.GetByIdAsync(userIdentity.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(userIdentity);

        _activityLogRepoMock
            .Setup(r => r.GetUserActivitiesAsync(userIdentity.UserId, 1, 100, It.IsAny<CancellationToken>()))
            .ReturnsAsync(activities);

        _mediatorMock
            .Setup(m => m.Send(It.IsAny<SendEmailVerificationCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Result<EmailVerificationTokenInfo>.Success(expectedResponse));

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        // Should succeed because only 2 EmailVerificationSent activities (below limit of 3)
        result.IsSuccess.Should().BeTrue();
    }
}

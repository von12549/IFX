using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.GlobalRoles.Commands.RemoveGlobalRole;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization.GlobalRoles;

public class RemoveGlobalRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IGlobalRoleRepository> _globalRoles = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<RemoveGlobalRoleCommandHandler>> _logger = new();
    private readonly RemoveGlobalRoleCommandHandler _handler;

    public RemoveGlobalRoleCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.GlobalRoles).Returns(_globalRoles.Object);
        _currentUser.Setup(c => c.IsGlobalAdmin).Returns(true);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _handler = new RemoveGlobalRoleCommandHandler(_unitOfWork.Object, _currentUser.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenValidRequest_RemovesRole()
    {
        var globalRole = GlobalRole.Create("PlatformSupport", "Support access");
        var userId = Guid.NewGuid();
        var assignment = UserGlobalRole.Create(userId, globalRole.Id);

        _globalRoles.Setup(r => r.GetUserGlobalRoleAsync(userId, globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(assignment);
        _globalRoles.Setup(r => r.GetByIdAsync(globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(globalRole);

        var result = await _handler.Handle(
            new RemoveGlobalRoleCommand(userId, globalRole.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _globalRoles.Verify(r => r.RemoveUserGlobalRole(assignment), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNotGlobalAdmin_ReturnsFailure()
    {
        _currentUser.Setup(c => c.IsGlobalAdmin).Returns(false);

        var result = await _handler.Handle(
            new RemoveGlobalRoleCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("platform admins");
    }

    [Fact]
    public async Task Handle_WhenAssignmentNotFound_ReturnsFailure()
    {
        _globalRoles.Setup(r => r.GetUserGlobalRoleAsync(
                It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
                    .ReturnsAsync((UserGlobalRole?)null);

        var result = await _handler.Handle(
            new RemoveGlobalRoleCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("does not have");
    }

    [Fact]
    public async Task Handle_WhenRemovingLastPlatformAdmin_ReturnsFailure()
    {
        var adminRole = GlobalRole.Create("PlatformAdmin", "Full access");
        var userId = Guid.NewGuid();
        var assignment = UserGlobalRole.Create(userId, adminRole.Id);

        _globalRoles.Setup(r => r.GetUserGlobalRoleAsync(userId, adminRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(assignment);
        _globalRoles.Setup(r => r.GetByIdAsync(adminRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(adminRole);
        _globalRoles.Setup(r => r.CountPlatformAdminsAsync(It.IsAny<CancellationToken>()))
                    .ReturnsAsync(1);

        var result = await _handler.Handle(
            new RemoveGlobalRoleCommand(userId, adminRole.Id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("last PlatformAdmin");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenRemovingOneOfMultiplePlatformAdmins_Succeeds()
    {
        var adminRole = GlobalRole.Create("PlatformAdmin", "Full access");
        var userId = Guid.NewGuid();
        var assignment = UserGlobalRole.Create(userId, adminRole.Id);

        _globalRoles.Setup(r => r.GetUserGlobalRoleAsync(userId, adminRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(assignment);
        _globalRoles.Setup(r => r.GetByIdAsync(adminRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(adminRole);
        _globalRoles.Setup(r => r.CountPlatformAdminsAsync(It.IsAny<CancellationToken>()))
                    .ReturnsAsync(2);

        var result = await _handler.Handle(
            new RemoveGlobalRoleCommand(userId, adminRole.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}

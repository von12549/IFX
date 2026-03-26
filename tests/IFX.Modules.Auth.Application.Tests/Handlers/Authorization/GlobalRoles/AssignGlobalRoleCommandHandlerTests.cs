using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.AssignGlobalRole;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization.GlobalRoles;

public class AssignGlobalRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IGlobalRoleRepository> _globalRoles = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<AssignGlobalRoleCommandHandler>> _logger = new();
    private readonly AssignGlobalRoleCommandHandler _handler;

    public AssignGlobalRoleCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.GlobalRoles).Returns(_globalRoles.Object);
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _currentUser.Setup(c => c.IsGlobalAdmin).Returns(true);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _handler = new AssignGlobalRoleCommandHandler(_unitOfWork.Object, _currentUser.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenValidRequest_AssignsRole()
    {
        var globalRole = GlobalRole.Create("PlatformSupport", "Support access");
        var user = new UserBuilder().Build();

        _globalRoles.Setup(r => r.GetByIdAsync(globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(globalRole);
        _users.Setup(u => u.GetByIdAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _globalRoles.Setup(r => r.GetUserGlobalRoleAsync(user.Id, globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync((UserGlobalRole?)null);

        var result = await _handler.Handle(
            new AssignGlobalRoleCommand(user.Id, globalRole.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _globalRoles.Verify(
            r => r.AddUserGlobalRoleAsync(It.IsAny<UserGlobalRole>(), It.IsAny<CancellationToken>()),
            Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenNotGlobalAdmin_ReturnsFailure()
    {
        _currentUser.Setup(c => c.IsGlobalAdmin).Returns(false);

        var result = await _handler.Handle(
            new AssignGlobalRoleCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("platform admins");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenGlobalRoleNotFound_ReturnsFailure()
    {
        _globalRoles.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
                    .ReturnsAsync((GlobalRole?)null);

        var result = await _handler.Handle(
            new AssignGlobalRoleCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenUserNotFound_ReturnsFailure()
    {
        var globalRole = GlobalRole.Create("PlatformSupport", "Support access");

        _globalRoles.Setup(r => r.GetByIdAsync(globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(globalRole);
        _users.Setup(u => u.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((User?)null);

        var result = await _handler.Handle(
            new AssignGlobalRoleCommand(Guid.NewGuid(), globalRole.Id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenAlreadyAssigned_ReturnsFailure()
    {
        var globalRole = GlobalRole.Create("PlatformSupport", "Support access");
        var user = new UserBuilder().Build();
        var existing = UserGlobalRole.Create(user.Id, globalRole.Id);

        _globalRoles.Setup(r => r.GetByIdAsync(globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(globalRole);
        _users.Setup(u => u.GetByIdAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _globalRoles.Setup(r => r.GetUserGlobalRoleAsync(user.Id, globalRole.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(existing);

        var result = await _handler.Handle(
            new AssignGlobalRoleCommand(user.Id, globalRole.Id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already has");
    }
}

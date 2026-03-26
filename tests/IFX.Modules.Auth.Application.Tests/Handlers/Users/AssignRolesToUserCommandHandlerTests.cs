using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Commands.AssignRolesToUser;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Users;

public class AssignRolesToUserCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<AssignRolesToUserCommandHandler>> _logger = new();
    private readonly AssignRolesToUserCommandHandler _handler;

    public AssignRolesToUserCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new AssignRolesToUserCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidUserAndRoles_AssignsAndReturnsTrue()
    {
        var user = new UserBuilder().Active().Build();
        var role = new RoleBuilder().AsUser().Build();
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _roles.Setup(r => r.GetByIdAsync(role.Id, It.IsAny<CancellationToken>())).ReturnsAsync(role);

        var result = await _handler.Handle(
            new AssignRolesToUserCommand(user.Id, [role.Id]), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenUserNotFound_ReturnsFailure()
    {
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((User?)null);

        var result = await _handler.Handle(
            new AssignRolesToUserCommand(Guid.NewGuid(), [Guid.NewGuid()]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User not found");
    }

    [Fact]
    public async Task Handle_WhenRoleNotFound_ReturnsFailure()
    {
        var user = new UserBuilder().Active().Build();
        var missingRoleId = Guid.NewGuid();
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _roles.Setup(r => r.GetByIdAsync(missingRoleId, It.IsAny<CancellationToken>())).ReturnsAsync((Role?)null);

        var result = await _handler.Handle(
            new AssignRolesToUserCommand(user.Id, [missingRoleId]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

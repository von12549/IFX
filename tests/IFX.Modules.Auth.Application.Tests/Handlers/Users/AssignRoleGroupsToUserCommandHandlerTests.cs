using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Commands.AssignRoleGroupsToUser;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Users;

public class AssignRoleGroupsToUserCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IRoleGroupRepository> _groups = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<AssignRoleGroupsToUserCommandHandler>> _logger = new();
    private readonly AssignRoleGroupsToUserCommandHandler _handler;

    public AssignRoleGroupsToUserCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _unitOfWork.Setup(u => u.RoleGroups).Returns(_groups.Object);
        _currentUser.SetupGet(u => u.IsAuthenticated).Returns(true);
        _currentUser.SetupGet(u => u.TenantId).Returns(Guid.NewGuid());
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new AssignRoleGroupsToUserCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidUserAndGroups_AssignsAndReturnsTrue()
    {
        var user = new UserBuilder().Active().Build();
        var group = RoleGroup.Create("Managers", "Managers", Guid.NewGuid());
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _groups.Setup(g => g.GetByIdAsync(group.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(group);

        var result = await _handler.Handle(
            new AssignRoleGroupsToUserCommand(user.Id, [group.Id]), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenUserNotFound_ReturnsFailure()
    {
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((User?)null);

        var result = await _handler.Handle(
            new AssignRoleGroupsToUserCommand(Guid.NewGuid(), [Guid.NewGuid()]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User not found");
    }

    [Fact]
    public async Task Handle_WhenGroupNotFound_ReturnsFailure()
    {
        var user = new UserBuilder().Active().Build();
        var missingGroupId = Guid.NewGuid();
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _groups.Setup(g => g.GetByIdAsync(missingGroupId, It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
               .ReturnsAsync((RoleGroup?)null);

        var result = await _handler.Handle(
            new AssignRoleGroupsToUserCommand(user.Id, [missingGroupId]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

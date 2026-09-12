using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Access.Assignments.Commands.RemoveRoleGroupFromUser;
using IFX.Modules.IAM.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Users;

public class RemoveRoleGroupFromUserCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<RemoveRoleGroupFromUserCommandHandler>> _logger = new();
    private readonly RemoveRoleGroupFromUserCommandHandler _handler;

    public RemoveRoleGroupFromUserCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new RemoveRoleGroupFromUserCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingUser_RemovesGroupAndReturnsTrue()
    {
        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);

        var result = await _handler.Handle(
            new RemoveRoleGroupFromUserCommand(user.Id, Guid.NewGuid()), CancellationToken.None);

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
            new RemoveRoleGroupFromUserCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User not found");
    }
}

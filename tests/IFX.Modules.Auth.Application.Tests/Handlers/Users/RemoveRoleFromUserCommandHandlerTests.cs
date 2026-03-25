using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Commands.RemoveRoleFromUser;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Users;

public class RemoveRoleFromUserCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<RemoveRoleFromUserCommandHandler>> _logger = new();
    private readonly RemoveRoleFromUserCommandHandler _handler;

    public RemoveRoleFromUserCommandHandlerTests()
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
        _handler = new RemoveRoleFromUserCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingUser_RemovesRoleAndReturnsTrue()
    {
        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);

        var result = await _handler.Handle(
            new RemoveRoleFromUserCommand(user.Id, Guid.NewGuid()), CancellationToken.None);

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
            new RemoveRoleFromUserCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User not found");
    }
}

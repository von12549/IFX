using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.DeleteRoleGroup;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class DeleteRoleGroupCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleGroupRepository> _groups = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<DeleteRoleGroupCommandHandler>> _logger = new();
    private readonly DeleteRoleGroupCommandHandler _handler;

    public DeleteRoleGroupCommandHandlerTests()
    {
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
        _handler = new DeleteRoleGroupCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingGroup_DeletesAndReturnsTrue()
    {
        var group = RoleGroup.Create("Managers", "Manager group", Guid.NewGuid());
        _groups.Setup(g => g.GetByIdAsync(group.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(group);

        var result = await _handler.Handle(new DeleteRoleGroupCommand(group.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeTrue();
        _groups.Verify(g => g.Remove(group), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenGroupNotFound_ReturnsFailure()
    {
        _groups.Setup(g => g.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
               .ReturnsAsync((RoleGroup?)null);

        var result = await _handler.Handle(new DeleteRoleGroupCommand(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Role group not found");
        _groups.Verify(g => g.Remove(It.IsAny<RoleGroup>()), Times.Never);
    }
}

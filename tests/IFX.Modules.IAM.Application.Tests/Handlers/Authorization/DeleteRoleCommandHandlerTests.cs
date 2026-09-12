using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.IAM.Application.Access.Roles.Commands.DeleteRole;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization;

public class DeleteRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<DeleteRoleCommandHandler>> _logger = new();
    private readonly DeleteRoleCommandHandler _handler;

    public DeleteRoleCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
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
        _handler = new DeleteRoleCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingRole_DeletesAndReturnsTrue()
    {
        var role = new RoleBuilder().AsAdmin().Build();
        _roles.Setup(r => r.GetByIdAsync(role.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(role);

        var result = await _handler.Handle(new DeleteRoleCommand(role.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeTrue();
        _roles.Verify(r => r.Remove(role), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenRoleNotFound_ReturnsFailure()
    {
        _roles.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((Role?)null);

        var result = await _handler.Handle(new DeleteRoleCommand(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Role not found");
        _roles.Verify(r => r.Remove(It.IsAny<Role>()), Times.Never);
    }
}

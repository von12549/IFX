using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.Roles.Commands.RemovePermissionFromRole;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class RemovePermissionFromRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<RemovePermissionFromRoleCommandHandler>> _logger = new();
    private readonly RemovePermissionFromRoleCommandHandler _handler;

    public RemovePermissionFromRoleCommandHandlerTests()
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
        _handler = new RemovePermissionFromRoleCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingRole_RemovesPermissionAndReturnsTrue()
    {
        var role = new RoleBuilder().AsAdmin().Build();
        var permId = Guid.NewGuid();
        _roles.Setup(r => r.GetByIdWithPermissionsAsync(role.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(role);

        var result = await _handler.Handle(
            new RemovePermissionFromRoleCommand(role.Id, permId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenRoleNotFound_ReturnsFailure()
    {
        _roles.Setup(r => r.GetByIdWithPermissionsAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((Role?)null);

        var result = await _handler.Handle(
            new RemovePermissionFromRoleCommand(Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Role not found");
    }
}

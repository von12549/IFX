using IFX.Modules.Auth.Application.Authorization.Permissions.Commands.DeletePermission;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class DeletePermissionCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPermissionRepository> _permissions = new();
    private readonly Mock<ILogger<DeletePermissionCommandHandler>> _logger = new();
    private readonly DeletePermissionCommandHandler _handler;

    public DeletePermissionCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Permissions).Returns(_permissions.Object);
        _handler = new DeletePermissionCommandHandler(_unitOfWork.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingPermission_DeletesAndReturnsTrue()
    {
        var permission = Permission.Create("Role.Read", "Read roles");
        _permissions.Setup(p => p.GetByIdAsync(permission.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(permission);

        var result = await _handler.Handle(new DeletePermissionCommand(permission.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeTrue();
        _permissions.Verify(p => p.Remove(permission), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenPermissionNotFound_ReturnsFailure()
    {
        _permissions.Setup(p => p.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
                    .ReturnsAsync((Permission?)null);

        var result = await _handler.Handle(new DeletePermissionCommand(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Permission not found");
        _permissions.Verify(p => p.Remove(It.IsAny<Permission>()), Times.Never);
    }
}

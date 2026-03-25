using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.Commands.AssignPermissionsToRole;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class AssignPermissionsToRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IPermissionRepository> _permissions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<AssignPermissionsToRoleCommandHandler>> _logger = new();
    private readonly AssignPermissionsToRoleCommandHandler _handler;

    public AssignPermissionsToRoleCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
        _unitOfWork.Setup(u => u.Permissions).Returns(_permissions.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new AssignPermissionsToRoleCommandHandler(_unitOfWork.Object, _mapper.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidRoleAndPermissions_AssignsAndReturnsDetail()
    {
        var role = new RoleBuilder().AsAdmin().Build();
        var permission = Permission.Create("Role.Read", "Read roles");
        _roles.Setup(r => r.GetByIdWithPermissionsAsync(role.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(role);
        _permissions.Setup(p => p.GetByIdAsync(permission.Id, It.IsAny<CancellationToken>()))
                    .ReturnsAsync(permission);
        _mapper.Setup(m => m.Map<RoleDetailDto>(role)).Returns(new RoleDetailDto { Id = role.Id });

        var result = await _handler.Handle(
            new AssignPermissionsToRoleCommand(role.Id, [permission.Id]), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenRoleNotFound_ReturnsFailure()
    {
        _roles.Setup(r => r.GetByIdWithPermissionsAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((Role?)null);

        var result = await _handler.Handle(
            new AssignPermissionsToRoleCommand(Guid.NewGuid(), [Guid.NewGuid()]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Role not found");
    }

    [Fact]
    public async Task Handle_WhenPermissionNotFound_ReturnsFailure()
    {
        var role = new RoleBuilder().AsAdmin().Build();
        var missingPermId = Guid.NewGuid();
        _roles.Setup(r => r.GetByIdWithPermissionsAsync(role.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(role);
        _permissions.Setup(p => p.GetByIdAsync(missingPermId, It.IsAny<CancellationToken>()))
                    .ReturnsAsync((Permission?)null);

        var result = await _handler.Handle(
            new AssignPermissionsToRoleCommand(role.Id, [missingPermId]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

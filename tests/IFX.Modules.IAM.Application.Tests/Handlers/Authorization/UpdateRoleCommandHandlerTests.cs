using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.IAM.Application.Access.Roles.Commands.UpdateRole;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization;

public class UpdateRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<UpdateRoleCommandHandler>> _logger = new();
    private readonly UpdateRoleCommandHandler _handler;

    public UpdateRoleCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new UpdateRoleCommandHandler(_unitOfWork.Object, _mapper.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingRole_UpdatesAndReturnsDto()
    {
        var role = new RoleBuilder().WithName("OldName").WithDescription("Old desc").Build();
        _roles.Setup(r => r.GetByIdAsync(role.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(role);
        _mapper.Setup(m => m.Map<RoleDto>(It.IsAny<Role>())).Returns(new RoleDto { Name = "NewName" });

        var result = await _handler.Handle(
            new UpdateRoleCommand(role.Id, "NewName", "New desc", role.TenantId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenRoleNotFound_ReturnsFailure()
    {
        _roles.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((Role?)null);

        var result = await _handler.Handle(
            new UpdateRoleCommand(Guid.NewGuid(), "Name", "Desc", Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Role not found");
    }

    [Fact]
    public async Task Handle_WhenNewNameAlreadyExists_ReturnsFailure()
    {
        var role = new RoleBuilder().WithName("OldName").Build();
        _roles.Setup(r => r.GetByIdAsync(role.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(role);
        _roles.Setup(r => r.NameExistsAsync("TakenName", role.TenantId, role.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(true);

        var result = await _handler.Handle(
            new UpdateRoleCommand(role.Id, "TakenName", "Desc", role.TenantId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
    }

    [Fact]
    public async Task Handle_WhenNameUnchanged_SkipsNameCheck()
    {
        var role = new RoleBuilder().WithName("SameName").Build();
        _roles.Setup(r => r.GetByIdAsync(role.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(role);
        _mapper.Setup(m => m.Map<RoleDto>(It.IsAny<Role>())).Returns(new RoleDto { Name = "SameName" });

        var result = await _handler.Handle(
            new UpdateRoleCommand(role.Id, "SameName", "Updated desc", role.TenantId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _roles.Verify(r => r.NameExistsAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

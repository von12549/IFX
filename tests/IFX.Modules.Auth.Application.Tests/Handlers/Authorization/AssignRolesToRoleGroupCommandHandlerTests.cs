using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.AssignRolesToRoleGroup;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class AssignRolesToRoleGroupCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleGroupRepository> _groups = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<AssignRolesToRoleGroupCommandHandler>> _logger = new();
    private readonly AssignRolesToRoleGroupCommandHandler _handler;

    public AssignRolesToRoleGroupCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.RoleGroups).Returns(_groups.Object);
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
        _handler = new AssignRolesToRoleGroupCommandHandler(_unitOfWork.Object, _mapper.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidGroupAndRoles_AssignsAndReturnsDto()
    {
        var group = RoleGroup.Create("Managers", "Managers", Guid.NewGuid());
        var role = new RoleBuilder().AsUser().Build();
        _groups.Setup(g => g.GetByIdWithRolesAsync(group.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(group);
        _roles.Setup(r => r.GetByIdAsync(role.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(role);
        _mapper.Setup(m => m.Map<RoleGroupDto>(group)).Returns(new RoleGroupDto { Id = group.Id });

        var result = await _handler.Handle(
            new AssignRolesToRoleGroupCommand(group.Id, [role.Id]), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenGroupNotFound_ReturnsFailure()
    {
        _groups.Setup(g => g.GetByIdWithRolesAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
               .ReturnsAsync((RoleGroup?)null);

        var result = await _handler.Handle(
            new AssignRolesToRoleGroupCommand(Guid.NewGuid(), [Guid.NewGuid()]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Role group not found");
    }

    [Fact]
    public async Task Handle_WhenRoleNotFound_ReturnsFailure()
    {
        var group = RoleGroup.Create("Managers", "Managers", Guid.NewGuid());
        var missingRoleId = Guid.NewGuid();
        _groups.Setup(g => g.GetByIdWithRolesAsync(group.Id, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(group);
        _roles.Setup(r => r.GetByIdAsync(missingRoleId, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Role?)null);

        var result = await _handler.Handle(
            new AssignRolesToRoleGroupCommand(group.Id, [missingRoleId]), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

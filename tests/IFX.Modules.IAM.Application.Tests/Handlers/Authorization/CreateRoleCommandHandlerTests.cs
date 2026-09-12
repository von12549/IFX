using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.IAM.Application.Access.Roles.Commands.CreateRole;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization;

public class CreateRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<CreateRoleCommandHandler>> _logger = new();
    private readonly CreateRoleCommandHandler _handler;

    public CreateRoleCommandHandlerTests()
    {
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new CreateRoleCommandHandler(_unitOfWork.Object, _mapper.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewName_CreatesRoleAndReturnsDto()
    {
        var tenantId = Guid.NewGuid();
        _roles.Setup(r => r.NameExistsAsync("Moderator", tenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<RoleDto>(It.IsAny<Role>())).Returns(new RoleDto { Name = "Moderator" });

        var result = await _handler.Handle(new CreateRoleCommand("Moderator", "Moderator role", tenantId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("Moderator");
        _roles.Verify(r => r.AddAsync(It.IsAny<Role>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNameAlreadyExists_ReturnsFailure()
    {
        var tenantId = Guid.NewGuid();
        _roles.Setup(r => r.NameExistsAsync("Admin", tenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(new CreateRoleCommand("Admin", "Admin role", tenantId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        _roles.Verify(r => r.AddAsync(It.IsAny<Role>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

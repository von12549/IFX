using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Commands.CreateRoleGroup;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class CreateRoleGroupCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleGroupRepository> _groups = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ILogger<CreateRoleGroupCommandHandler>> _logger = new();
    private readonly CreateRoleGroupCommandHandler _handler;

    public CreateRoleGroupCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.RoleGroups).Returns(_groups.Object);
        _handler = new CreateRoleGroupCommandHandler(_unitOfWork.Object, _mapper.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewName_CreatesGroupAndReturnsDto()
    {
        var tenantId = Guid.NewGuid();
        _groups.Setup(g => g.NameExistsAsync("Managers", tenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<RoleGroupDto>(It.IsAny<RoleGroup>()))
               .Returns(new RoleGroupDto { Name = "Managers" });

        var result = await _handler.Handle(
            new CreateRoleGroupCommand("Managers", "Manager group", tenantId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("Managers");
        _groups.Verify(g => g.AddAsync(It.IsAny<RoleGroup>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenNameAlreadyExists_ReturnsFailure()
    {
        var tenantId = Guid.NewGuid();
        _groups.Setup(g => g.NameExistsAsync("Managers", tenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(
            new CreateRoleGroupCommand("Managers", "Manager group", tenantId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        _groups.Verify(g => g.AddAsync(It.IsAny<RoleGroup>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

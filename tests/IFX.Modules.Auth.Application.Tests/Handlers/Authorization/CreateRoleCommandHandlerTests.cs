using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Commands.CreateRole;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class CreateRoleCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ILogger<CreateRoleCommandHandler>> _logger = new();
    private readonly CreateRoleCommandHandler _handler;

    public CreateRoleCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
        _handler = new CreateRoleCommandHandler(_unitOfWork.Object, _mapper.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewName_CreatesRoleAndReturnsDto()
    {
        _roles.Setup(r => r.NameExistsAsync("Moderator", It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<RoleDto>(It.IsAny<Role>())).Returns(new RoleDto { Name = "Moderator" });

        var result = await _handler.Handle(new CreateRoleCommand("Moderator", "Moderator role"), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("Moderator");
        _roles.Verify(r => r.AddAsync(It.IsAny<Role>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenNameAlreadyExists_ReturnsFailure()
    {
        _roles.Setup(r => r.NameExistsAsync("Admin", It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(new CreateRoleCommand("Admin", "Admin role"), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        _roles.Verify(r => r.AddAsync(It.IsAny<Role>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

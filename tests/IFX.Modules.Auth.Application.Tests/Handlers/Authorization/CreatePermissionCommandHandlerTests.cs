using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Commands.CreatePermission;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class CreatePermissionCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPermissionRepository> _permissions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ILogger<CreatePermissionCommandHandler>> _logger = new();
    private readonly CreatePermissionCommandHandler _handler;

    public CreatePermissionCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.Permissions).Returns(_permissions.Object);
        _handler = new CreatePermissionCommandHandler(_unitOfWork.Object, _mapper.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewName_CreatesPermissionAndReturnsDto()
    {
        _permissions.Setup(p => p.NameExistsAsync("Reports.Read", It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<PermissionDto>(It.IsAny<Permission>()))
               .Returns(new PermissionDto { Name = "Reports.Read" });

        var result = await _handler.Handle(
            new CreatePermissionCommand("Reports.Read", "Read reports"), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("Reports.Read");
        _permissions.Verify(p => p.AddAsync(It.IsAny<Permission>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenNameAlreadyExists_ReturnsFailure()
    {
        _permissions.Setup(p => p.NameExistsAsync("Role.Read", It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(
            new CreatePermissionCommand("Role.Read", "Read roles"), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        _permissions.Verify(p => p.AddAsync(It.IsAny<Permission>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

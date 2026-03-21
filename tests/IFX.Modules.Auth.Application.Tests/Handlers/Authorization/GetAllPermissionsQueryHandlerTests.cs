using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Authorization.Queries.GetAllPermissions;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class GetAllPermissionsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPermissionRepository> _permissions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ILogger<GetAllPermissionsQueryHandler>> _logger = new();
    private readonly GetAllPermissionsQueryHandler _handler;

    public GetAllPermissionsQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.Permissions).Returns(_permissions.Object);
        _handler = new GetAllPermissionsQueryHandler(_unitOfWork.Object, _mapper.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsAllPermissions()
    {
        var permList = new List<Permission>
        {
            Permission.Create("Role.Read", "Read roles"),
            Permission.Create("User.Read", "Read users"),
        };
        _permissions.Setup(p => p.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync(permList);
        _mapper.Setup(m => m.Map<List<PermissionDto>>(permList))
               .Returns([new PermissionDto { Name = "Role.Read" }, new PermissionDto { Name = "User.Read" }]);

        var result = await _handler.Handle(new GetAllPermissionsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenNoPermissions_ReturnsEmptyList()
    {
        _permissions.Setup(p => p.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);
        _mapper.Setup(m => m.Map<List<PermissionDto>>(It.IsAny<List<Permission>>())).Returns([]);

        var result = await _handler.Handle(new GetAllPermissionsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
    }
}

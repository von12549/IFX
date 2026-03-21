using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoles;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class GetAllRolesQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ILogger<GetAllRolesQueryHandler>> _logger = new();
    private readonly GetAllRolesQueryHandler _handler;

    public GetAllRolesQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.Roles).Returns(_roles.Object);
        _handler = new GetAllRolesQueryHandler(_unitOfWork.Object, _mapper.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsAllRoles()
    {
        var roleList = new List<Role>
        {
            new RoleBuilder().AsAdmin().Build(),
            new RoleBuilder().AsUser().Build(),
        };
        _roles.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync(roleList);
        _mapper.Setup(m => m.Map<List<RoleDto>>(roleList))
               .Returns([new RoleDto { Name = "Admin" }, new RoleDto { Name = "User" }]);

        var result = await _handler.Handle(new GetAllRolesQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenNoRoles_ReturnsEmptyList()
    {
        _roles.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);
        _mapper.Setup(m => m.Map<List<RoleDto>>(It.IsAny<List<Role>>())).Returns([]);

        var result = await _handler.Handle(new GetAllRolesQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
    }
}

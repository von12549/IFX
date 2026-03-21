using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoleGroups;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class GetAllRoleGroupsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleGroupRepository> _groups = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ILogger<GetAllRoleGroupsQueryHandler>> _logger = new();
    private readonly GetAllRoleGroupsQueryHandler _handler;

    public GetAllRoleGroupsQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.RoleGroups).Returns(_groups.Object);
        _handler = new GetAllRoleGroupsQueryHandler(_unitOfWork.Object, _mapper.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsAllRoleGroups()
    {
        var groupList = new List<RoleGroup>
        {
            RoleGroup.Create("Managers", "Manager group"),
            RoleGroup.Create("Admins", "Admin group"),
        };
        _groups.Setup(g => g.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync(groupList);
        _mapper.Setup(m => m.Map<List<RoleGroupDto>>(groupList))
               .Returns([new RoleGroupDto { Name = "Managers" }, new RoleGroupDto { Name = "Admins" }]);

        var result = await _handler.Handle(new GetAllRoleGroupsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenNoGroups_ReturnsEmptyList()
    {
        _groups.Setup(g => g.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);
        _mapper.Setup(m => m.Map<List<RoleGroupDto>>(It.IsAny<List<RoleGroup>>())).Returns([]);

        var result = await _handler.Handle(new GetAllRoleGroupsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
    }
}

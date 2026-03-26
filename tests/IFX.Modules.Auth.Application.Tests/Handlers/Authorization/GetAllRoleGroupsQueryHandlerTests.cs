using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.Queries.GetAllRoleGroups;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

public class GetAllRoleGroupsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IRoleGroupRepository> _groups = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetAllRoleGroupsQueryHandler>> _logger = new();
    private readonly GetAllRoleGroupsQueryHandler _handler;

    public GetAllRoleGroupsQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.RoleGroups).Returns(_groups.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new GetAllRoleGroupsQueryHandler(_unitOfWork.Object, _mapper.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithTenantId_ReturnsFilteredRoleGroups()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(tenantId);
        var groupList = new List<RoleGroup>
        {
            RoleGroup.Create("Managers", "Manager group", tenantId),
            RoleGroup.Create("Admins", "Admin group", tenantId),
        };
        _groups.Setup(g => g.GetByTenantIdAsync(tenantId, It.IsAny<CancellationToken>())).ReturnsAsync(groupList);
        _mapper.Setup(m => m.Map<List<RoleGroupDto>>(groupList))
               .Returns([new RoleGroupDto { Name = "Managers" }, new RoleGroupDto { Name = "Admins" }]);

        var result = await _handler.Handle(new GetAllRoleGroupsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WithNullTenantId_ReturnsEmpty()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetAllRoleGroupsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
    }
}

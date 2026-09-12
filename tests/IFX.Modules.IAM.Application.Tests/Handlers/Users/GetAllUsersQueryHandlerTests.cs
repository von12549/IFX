using IFX.Modules.IAM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Application.Users.Queries.GetAllUsers;
using IFX.Modules.IAM.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Users;

public class GetAllUsersQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetAllUsersQueryHandler>> _logger = new();
    private readonly GetAllUsersQueryHandler _handler;

    public GetAllUsersQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new GetAllUsersQueryHandler(_unitOfWork.Object, _mapper.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithTenantId_ReturnsPagedUserList()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(tenantId);
        var userList = new List<User> { new UserBuilder().Active().Build() };
        _users.Setup(u => u.GetAllUsersByTenantAsync(tenantId, 1, 10, It.IsAny<CancellationToken>()))
              .ReturnsAsync((userList, 1));
        _mapper.Setup(m => m.Map<IEnumerable<UserProfileDto>>(userList))
               .Returns([new UserProfileDto()]);

        var result = await _handler.Handle(new GetAllUsersQuery(1, 10), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.TotalCount.Should().Be(1);
        result.Value.Items.Should().HaveCount(1);
    }

    [Fact]
    public async Task Handle_WithNullTenantId_ReturnsEmptyPagedResult()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetAllUsersQuery(1, 10), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.TotalCount.Should().Be(0);
        result.Value.Items.Should().BeEmpty();
    }
}

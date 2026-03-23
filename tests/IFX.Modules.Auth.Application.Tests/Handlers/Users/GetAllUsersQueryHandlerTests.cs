using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Users.Queries.GetAllUsers;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Users;

public class GetAllUsersQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<GetAllUsersQueryHandler>> _logger = new();
    private readonly GetAllUsersQueryHandler _handler;

    public GetAllUsersQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _handler = new GetAllUsersQueryHandler(_unitOfWork.Object, _mapper.Object, _currentUser.Object, _logger.Object);
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

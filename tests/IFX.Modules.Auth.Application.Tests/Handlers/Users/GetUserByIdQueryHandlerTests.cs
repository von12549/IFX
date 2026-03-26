using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Users.Queries.GetUserById;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Users;

public class GetUserByIdQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetUserByIdQueryHandler>> _logger = new();
    private readonly GetUserByIdQueryHandler _handler;

    public GetUserByIdQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new GetUserByIdQueryHandler(_unitOfWork.Object, _mapper.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingUser_ReturnsUserProfile()
    {
        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(user.Id, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _mapper.Setup(m => m.Map<UserProfileDto>(user))
               .Returns(new UserProfileDto { Id = user.Id });

        var result = await _handler.Handle(new GetUserByIdQuery(user.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Id.Should().Be(user.Id);
    }

    [Fact]
    public async Task Handle_WhenUserNotFound_ReturnsFailure()
    {
        _users.Setup(u => u.GetByIdWithRolesAndGroupsAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((User?)null);

        var result = await _handler.Handle(new GetUserByIdQuery(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User not found");
    }
}

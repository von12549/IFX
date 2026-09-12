using IFX.Modules.IAM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;

using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Application.Users.Queries.GetUserProfile;
using IFX.Modules.IAM.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Users;

public class GetUserProfileQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetUserProfileQueryHandler>> _logger = new();
    private readonly GetUserProfileQueryHandler _handler;

    public GetUserProfileQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.Users).Returns(_users.Object);

        // Authorization passes by default in unit tests
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new GetUserProfileQueryHandler(
            _unitOfWork.Object,
            _mapper.Object,
            _currentUser.Object,
            _authorizationService.Object,
            _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingUser_ReturnsUserProfile()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(tenantId);

        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIssuerAndSubjectWithPermissionsAsync(
                TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _mapper.Setup(m => m.Map<UserProfileDto>(user))
               .Returns(new UserProfileDto { Id = user.Id, DisplayName = user.DisplayName });

        var result = await _handler.Handle(
            new GetUserProfileQuery(TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Id.Should().Be(user.Id);
    }

    [Fact]
    public async Task Handle_AuthorizesViaResolvedUserReadPolicy()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(tenantId);

        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIssuerAndSubjectWithPermissionsAsync(
                TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _mapper.Setup(m => m.Map<UserProfileDto>(user))
               .Returns(new UserProfileDto { Id = user.Id, DisplayName = user.DisplayName });

        await _handler.Handle(
            new GetUserProfileQuery(TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject),
            CancellationToken.None);

        _authorizationService.Verify(a => a.AuthorizeWithResolvedPolicyAsync(
            "user",
            "read",
            It.IsAny<ResourceAttributes>(),
            It.IsAny<IDictionary<string, object>?>(),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WithNonPrimaryTenant_UsesSelectedTenantForAuthorization()
    {
        // The ABAC check uses the selected tenant (ICurrentUser.TenantId), not user.PrimaryTenantId.
        var selectedTenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(selectedTenantId);

        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIssuerAndSubjectWithPermissionsAsync(
                TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _mapper.Setup(m => m.Map<UserProfileDto>(user))
               .Returns(new UserProfileDto { Id = user.Id, DisplayName = user.DisplayName });

        var result = await _handler.Handle(
            new GetUserProfileQuery(TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _authorizationService.Verify(a => a.AuthorizeWithResolvedPolicyAsync(
            "user",
            "read",
            It.Is<ResourceAttributes>(r => r.TenantId == selectedTenantId.ToString()),
            It.IsAny<IDictionary<string, object>?>(),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenAuthorizationDenied_ReturnsFailure()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(tenantId);

        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ForbiddenException("Access denied by policy."));

        var user = new UserBuilder().Active().Build();
        _users.Setup(u => u.GetByIssuerAndSubjectWithPermissionsAsync(
                TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);

        var result = await _handler.Handle(
            new GetUserProfileQuery(TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
    }

    [Fact]
    public async Task Handle_WhenUserNotFound_ReturnsFailure()
    {
        _users.Setup(u => u.GetByIssuerAndSubjectWithPermissionsAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((User?)null);

        var result = await _handler.Handle(
            new GetUserProfileQuery("issuer", "subject"), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("User not found");
    }
}

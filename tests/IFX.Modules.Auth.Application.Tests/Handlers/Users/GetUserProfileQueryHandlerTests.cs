using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Users.Queries.GetUserProfile;
using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Users;

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
            .Setup(a => a.AuthorizeAsync(
                It.IsAny<string?>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<string>(),
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
    public async Task Handle_WithNonPrimaryTenant_UsesSelectedTenantForAuthorization()
    {
        // User's primary tenant differs from their currently selected tenant —
        // the ABAC check should use the selected tenant so same_tenant passes.
        var selectedTenantId = Guid.NewGuid();
        _currentUser.Setup(c => c.TenantId).Returns(selectedTenantId);

        var user = new UserBuilder().Active().Build(); // PrimaryTenantId is different
        _users.Setup(u => u.GetByIssuerAndSubjectWithPermissionsAsync(
                TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject, It.IsAny<CancellationToken>()))
              .ReturnsAsync(user);
        _mapper.Setup(m => m.Map<UserProfileDto>(user))
               .Returns(new UserProfileDto { Id = user.Id, DisplayName = user.DisplayName });

        var result = await _handler.Handle(
            new GetUserProfileQuery(TestConstants.IFXCognitoIssuer, TestConstants.ValidSubject),
            CancellationToken.None);

        // Should succeed — resource tenant is now the selected tenant, not user.PrimaryTenantId
        result.IsSuccess.Should().BeTrue();
        _authorizationService.Verify(a => a.AuthorizeAsync(
            null,
            "authz/auth/read_user",
            It.Is<OpaResourceAttributesBase>(r => r.TenantId == selectedTenantId.ToString()),
            "read",
            It.IsAny<CancellationToken>()), Times.Once);
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

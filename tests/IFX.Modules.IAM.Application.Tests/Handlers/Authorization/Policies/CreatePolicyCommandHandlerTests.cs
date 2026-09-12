using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization.Policies;

public class CreatePolicyCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPolicyDefinitionRepository> _policies = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<CreatePolicyCommandHandler>> _logger = new();
    private readonly CreatePolicyCommandHandler _handler;

    private static readonly List<PolicyConditionDto> ValidConditions =
        [new PolicyConditionDto("SameTenant", null)];

    public CreatePolicyCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.PolicyDefinitions).Returns(_policies.Object);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new CreatePolicyCommandHandler(
            _unitOfWork.Object,
            _currentUser.Object,
            _authorizationService.Object,
            _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidInput_CreatesPolicyAndReturnsDto()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.SetupGet(x => x.TenantId).Returns(tenantId);
        _policies.Setup(p => p.ExistsAsync(tenantId, "user", "read", It.IsAny<CancellationToken>()))
                 .ReturnsAsync(false);

        var result = await _handler.Handle(
            new CreatePolicyCommand(PolicyScope.Tenant, tenantId, "Read Own Profile", null, "user", "read", ValidConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("Read Own Profile");
        result.Value.ResourceType.Should().Be("user");
        result.Value.Action.Should().Be("read");
        result.Value.IsPlatformDefault.Should().BeFalse();

        _policies.Verify(p => p.AddAsync(It.IsAny<PolicyDefinition>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenDuplicateExists_ReturnsFailure()
    {
        var tenantId = Guid.NewGuid();
        _currentUser.SetupGet(x => x.TenantId).Returns(tenantId);
        _policies.Setup(p => p.ExistsAsync(tenantId, "user", "read", It.IsAny<CancellationToken>()))
                 .ReturnsAsync(true);

        var result = await _handler.Handle(
            new CreatePolicyCommand(PolicyScope.Tenant, tenantId, "Read Own Profile", null, "user", "read", ValidConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        _policies.Verify(p => p.AddAsync(It.IsAny<PolicyDefinition>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WithNullTenantId_CreatesPlatformPolicyAndCallsInvalidatePlatform()
    {
        _currentUser.SetupGet(x => x.IsGlobalAdmin).Returns(true);
        _policies.Setup(p => p.ExistsPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                 .ReturnsAsync(false);

        var result = await _handler.Handle(
            new CreatePolicyCommand(PolicyScope.Platform, null, "Read Own Profile (Platform)", null, "user", "read", ValidConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.TenantId.Should().BeNull();
        result.Value.IsPlatformDefault.Should().BeTrue();

        _policies.Verify(p => p.AddAsync(It.IsAny<PolicyDefinition>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenPlatformDuplicateExists_ReturnsFailure()
    {
        _currentUser.SetupGet(x => x.IsGlobalAdmin).Returns(true);
        _policies.Setup(p => p.ExistsPlatformAsync("user", "read", It.IsAny<CancellationToken>()))
                 .ReturnsAsync(true);

        var result = await _handler.Handle(
            new CreatePolicyCommand(PolicyScope.Platform, null, "Read Own Profile (Platform)", null, "user", "read", ValidConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists").And.Contain("platform");
        _policies.Verify(p => p.AddAsync(It.IsAny<PolicyDefinition>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

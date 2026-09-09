using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.Policies.Commands.DeletePolicy;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization.Policies;

public class DeletePolicyCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPolicyDefinitionRepository> _policies = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IAbacPolicyCache> _policyCache = new();
    private readonly Mock<ILogger<DeletePolicyCommandHandler>> _logger = new();
    private readonly DeletePolicyCommandHandler _handler;

    public DeletePolicyCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.PolicyDefinitions).Returns(_policies.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new DeletePolicyCommandHandler(_unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _policyCache.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingPolicy_RemovesAndReturnsSuccess()
    {
        var policyId = Guid.NewGuid();
        var existing = PolicyDefinition.Create(
            PolicyScope.Tenant, Guid.NewGuid(), "Read Own Profile", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]", null);
        _currentUser.Setup(c => c.TenantId).Returns(existing.TenantId);

        _policies.Setup(p => p.GetTenantByIdAsync(policyId, existing.TenantId!.Value, It.IsAny<CancellationToken>()))
                 .ReturnsAsync(existing);

        var result = await _handler.Handle(new DeletePolicyCommand(policyId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _policies.Verify(p => p.Remove(existing), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _policyCache.Verify(c => c.Invalidate(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenPolicyNotFound_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns(Guid.NewGuid());
        _policies.Setup(p => p.GetTenantByIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync((PolicyDefinition?)null);

        var result = await _handler.Handle(new DeletePolicyCommand(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _policies.Verify(p => p.Remove(It.IsAny<PolicyDefinition>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WithPlatformPolicy_CallsInvalidatePlatformInsteadOfInvalidate()
    {
        var policyId = Guid.NewGuid();
        var existing = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read Own Profile (Platform Default)", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]", null);
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        _policies.Setup(p => p.GetPlatformByIdAsync(policyId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync(existing);

        var result = await _handler.Handle(new DeletePolicyCommand(policyId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _policyCache.Verify(c => c.InvalidatePlatform("user", "read"), Times.Once);
        _policyCache.Verify(c => c.Invalidate(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }
}

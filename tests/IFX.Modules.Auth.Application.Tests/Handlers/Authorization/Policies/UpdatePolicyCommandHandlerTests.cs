using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Auth.Application.Authorization.Policies.Commands.UpdatePolicy;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization.Policies;

public class UpdatePolicyCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPolicyDefinitionRepository> _policies = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IAbacPolicyCache> _policyCache = new();
    private readonly Mock<ILogger<UpdatePolicyCommandHandler>> _logger = new();
    private readonly UpdatePolicyCommandHandler _handler;

    private static readonly List<PolicyConditionDto> UpdatedConditions =
        [new PolicyConditionDto("SameTenant", null), new PolicyConditionDto("CreatedByMe", null)];

    public UpdatePolicyCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.PolicyDefinitions).Returns(_policies.Object);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new UpdatePolicyCommandHandler(
            _unitOfWork.Object,
            _currentUser.Object,
            _authorizationService.Object,
            _policyCache.Object,
            _logger.Object);
    }

    [Fact]
    public async Task Handle_WithExistingPolicy_UpdatesAndReturnsDto()
    {
        var tenantId = Guid.NewGuid();
        var policyId = Guid.NewGuid();
        var existing = PolicyDefinition.Create(PolicyScope.Tenant, tenantId, "Old Name", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]", null);

        _policies.Setup(p => p.GetByIdAsync(policyId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync(existing);

        var result = await _handler.Handle(
            new UpdatePolicyCommand(policyId, "New Name", null, UpdatedConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("New Name");
        result.Value.Conditions.Should().HaveCount(2);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _policyCache.Verify(c => c.Invalidate(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenPolicyNotFound_ReturnsFailure()
    {
        _policies.Setup(p => p.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync((PolicyDefinition?)null);

        var result = await _handler.Handle(
            new UpdatePolicyCommand(Guid.NewGuid(), "Name", null, UpdatedConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

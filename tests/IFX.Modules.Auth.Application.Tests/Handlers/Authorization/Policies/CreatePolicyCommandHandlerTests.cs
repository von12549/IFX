using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Policies.Commands.CreatePolicy;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization.Policies;

public class CreatePolicyCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPolicyDefinitionRepository> _policies = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IAbacPolicyCache> _policyCache = new();
    private readonly Mock<ILogger<CreatePolicyCommandHandler>> _logger = new();
    private readonly CreatePolicyCommandHandler _handler;

    private static readonly List<PolicyConditionDto> ValidConditions =
        [new PolicyConditionDto("SameTenant", null)];

    public CreatePolicyCommandHandlerTests()
    {
        _unitOfWork.Setup(u => u.PolicyDefinitions).Returns(_policies.Object);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());

        _handler = new CreatePolicyCommandHandler(
            _unitOfWork.Object,
            _currentUser.Object,
            _policyCache.Object,
            _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidInput_CreatesPolicyAndReturnsDto()
    {
        var tenantId = Guid.NewGuid();
        _policies.Setup(p => p.ExistsAsync(tenantId, "user", "read", It.IsAny<CancellationToken>()))
                 .ReturnsAsync(false);

        var result = await _handler.Handle(
            new CreatePolicyCommand(tenantId, "Read Own Profile", "user", "read", ValidConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Name.Should().Be("Read Own Profile");
        result.Value.ResourceType.Should().Be("user");
        result.Value.Action.Should().Be("read");
        result.Value.IsPlatformDefault.Should().BeFalse();

        _policies.Verify(p => p.AddAsync(It.IsAny<PolicyDefinition>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _policyCache.Verify(c => c.Invalidate(tenantId, "user", "read"), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenDuplicateExists_ReturnsFailure()
    {
        var tenantId = Guid.NewGuid();
        _policies.Setup(p => p.ExistsAsync(tenantId, "user", "read", It.IsAny<CancellationToken>()))
                 .ReturnsAsync(true);

        var result = await _handler.Handle(
            new CreatePolicyCommand(tenantId, "Read Own Profile", "user", "read", ValidConditions),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        _policies.Verify(p => p.AddAsync(It.IsAny<PolicyDefinition>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

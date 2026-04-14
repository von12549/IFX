using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.Commands.CreatePartyRelationship;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.Parties;

public class CreatePartyRelationshipCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPartyRelationshipRepository> _relationships = new();
    private readonly Mock<IPartyRoleAssignmentRepository> _roleAssignments = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IIntegrationEventBus> _eventBus = new();
    private readonly Mock<ILogger<CreatePartyRelationshipCommandHandler>> _logger = new();
    private readonly CreatePartyRelationshipCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid FromPartyId = Guid.NewGuid();
    private static readonly Guid ToPartyId = Guid.NewGuid();
    private static readonly DateOnly Today = DateOnly.FromDateTime(DateTime.UtcNow);

    public CreatePartyRelationshipCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.PartyRelationships).Returns(_relationships.Object);
        _unitOfWork.Setup(u => u.PartyRoleAssignments).Returns(_roleAssignments.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _eventBus
            .Setup(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new CreatePartyRelationshipCommandHandler(
            _unitOfWork.Object, _currentUser.Object,
            _authorizationService.Object, _eventBus.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_AuthorizedToAdvise_WithAdvisoryFromParty_CreatesRelationshipAndPublishesEvent()
    {
        var command = new CreatePartyRelationshipCommand(FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        _roleAssignments.Setup(r => r.HasRoleAsync(FromPartyId, PartyFunctionalRole.AdvisorRep, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        _relationships.Setup(r => r.GetAsync(FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync((Domain.Entities.PartyRelationship?)null);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _relationships.Verify(r => r.AddAsync(It.IsAny<Domain.Entities.PartyRelationship>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _eventBus.Verify(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_AuthorizedToAdvise_WhenFromPartyLacksAdvisoryRole_ReturnsFailure()
    {
        var command = new CreatePartyRelationshipCommand(FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        _roleAssignments.Setup(r => r.HasRoleAsync(It.IsAny<Guid>(), It.IsAny<PartyFunctionalRole>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("advisory role");
        _relationships.Verify(r => r.AddAsync(It.IsAny<Domain.Entities.PartyRelationship>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenActiveRelationshipExists_ReturnsFailure()
    {
        var command = new CreatePartyRelationshipCommand(FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        _roleAssignments.Setup(r => r.HasRoleAsync(FromPartyId, PartyFunctionalRole.AdvisorRep, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        var existing = Domain.Entities.PartyRelationship.Create(TenantId, FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);
        _relationships.Setup(r => r.GetAsync(FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(existing);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);
        var command = new CreatePartyRelationshipCommand(FromPartyId, ToPartyId, PartyRelationshipType.AuthorizedToAdvise, Today);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}

using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.Commands.CreateParty;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.Parties;

public class CreatePartyCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPartyRepository> _parties = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<CreatePartyCommandHandler>> _logger = new();
    private readonly CreatePartyCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public CreatePartyCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Parties).Returns(_parties.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new CreatePartyCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewCode_CreatesPartyAndReturnsDto()
    {
        _parties.Setup(r => r.CodeExistsAsync("PTY001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<PartyDto>(It.IsAny<Party>())).Returns(new PartyDto { PartyCode = "PTY001" });

        var result = await _handler.Handle(new CreatePartyCommand("PTY001", "Acme Ltd", PartyLegalStructure.Company), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.PartyCode.Should().Be("PTY001");
        _parties.Verify(r => r.AddAsync(It.IsAny<Party>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenCodeAlreadyExists_ReturnsFailure()
    {
        _parties.Setup(r => r.CodeExistsAsync("PTY001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(new CreatePartyCommand("PTY001", "Acme Ltd", PartyLegalStructure.Company), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("PTY001");
        _parties.Verify(r => r.AddAsync(It.IsAny<Party>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new CreatePartyCommand("PTY001", "Acme Ltd", PartyLegalStructure.Company), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_SetsCreatedByFromCurrentUser()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(userId);
        _parties.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        Party? capturedParty = null;
        _parties.Setup(r => r.AddAsync(It.IsAny<Party>(), It.IsAny<CancellationToken>()))
            .Callback<Party, CancellationToken>((p, _) => capturedParty = p)
            .Returns(Task.CompletedTask);

        await _handler.Handle(new CreatePartyCommand("PTY002", "Beta Ltd", PartyLegalStructure.Company), CancellationToken.None);

        capturedParty.Should().NotBeNull();
        capturedParty!.CreatedBy.Should().Be(userId);
    }
}

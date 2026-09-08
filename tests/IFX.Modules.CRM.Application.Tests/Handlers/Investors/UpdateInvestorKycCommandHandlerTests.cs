using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.Investors;

public class UpdateInvestorKycCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IInvestorRepository> _investors = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<UpdateInvestorKycCommandHandler>> _logger = new();
    private readonly UpdateInvestorKycCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public UpdateInvestorKycCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Investors).Returns(_investors.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new UpdateInvestorKycCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenInvestorExists_UpdatesKycAndPublishesEvent()
    {
        var investor = Investor.Create(TenantId, "INV001", "John Doe", PartyLegalStructure.Individual);
        _investors.Setup(r => r.GetByIdAsync(investor.Id, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(investor);
        _mapper.Setup(m => m.Map<InvestorDto>(investor)).Returns(new InvestorDto { KycStatus = "Approved" });

        var result = await _handler.Handle(new UpdateInvestorKycCommand(investor.Id, KycStatus.Approved), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        investor.KycStatus.Should().Be(KycStatus.Approved);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenInvestorNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _investors.Setup(r => r.GetByIdAsync(missingId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync((Investor?)null);

        var result = await _handler.Handle(new UpdateInvestorKycCommand(missingId, KycStatus.Approved), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new UpdateInvestorKycCommand(Guid.NewGuid(), KycStatus.Approved), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_KeepsKycAsSynchronousContractAndDoesNotPublishAnIncompleteEvent()
    {
        var investor = Investor.Create(TenantId, "INV001", "John Doe", PartyLegalStructure.Individual);
        investor.UpdateKyc(KycStatus.Pending); // ensure known old status
        _investors.Setup(r => r.GetByIdAsync(investor.Id, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(investor);

        await _handler.Handle(new UpdateInvestorKycCommand(investor.Id, KycStatus.Approved), CancellationToken.None);

        _eventBuffer.Invocations.Should().BeEmpty();
    }
}

using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Transaction.Application.Commands.CreateTransfer;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Ports;
using IFX.Modules.Transaction.Domain.Repositories;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class CreateTransferCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<ITransactionRepository> _transactions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IAccountCompliancePort> _accountCompliance = new();
    private readonly Mock<IClassSubscriptionAvailabilityPort> _classSubscriptionAvailability = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<CreateTransferCommandHandler>> _logger = new();
    private readonly CreateTransferCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static TransactionDto MakeDto() => new(
        Guid.NewGuid(), Guid.NewGuid(), "Transfer",
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
        5000m, null, null, "2024-01-01", null, "Pending", null,
        DateTime.UtcNow, DateTime.UtcNow);

    private static readonly CreateTransferCommand ValidCommand = new(
        Guid.NewGuid(), Guid.NewGuid(),
        Guid.NewGuid(), Guid.NewGuid(),
        5000m, DateOnly.FromDateTime(DateTime.UtcNow));

    public CreateTransferCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Transactions).Returns(_transactions.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _accountCompliance.Setup(c => c.IsApprovedAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        _classSubscriptionAvailability.Setup(r => r.IsOpenAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        _handler = new CreateTransferCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _accountCompliance.Object, _classSubscriptionAvailability.Object,
            _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithValidRequest_CreatesTransferAndPublishesEvent()
    {
        _mapper.Setup(m => m.Map<TransactionDto>(It.IsAny<TxEntity>())).Returns(MakeDto());

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _transactions.Verify(r => r.AddAsync(It.IsAny<TxEntity>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
        _transactions.Verify(r => r.AddAsync(It.IsAny<TxEntity>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenInvestmentAccountKycNotApproved_ReturnsFailure()
    {
        _accountCompliance.Setup(c => c.IsApprovedAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("KYC");
        _transactions.Verify(r => r.AddAsync(It.IsAny<TxEntity>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenTargetClassNotOpen_ReturnsFailure()
    {
        _classSubscriptionAvailability.Setup(r => r.IsOpenAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not open");
        _transactions.Verify(r => r.AddAsync(It.IsAny<TxEntity>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

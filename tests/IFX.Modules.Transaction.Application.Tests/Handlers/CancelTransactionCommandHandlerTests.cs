using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Transaction.Application.Commands.CancelTransaction;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class CancelTransactionCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<ITransactionRepository> _transactions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IIntegrationEventBus> _eventBus = new();
    private readonly Mock<ILogger<CancelTransactionCommandHandler>> _logger = new();
    private readonly CancelTransactionCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    private static TransactionDto MakeDto() => new(
        Guid.NewGuid(), Guid.NewGuid(), "Subscription",
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), null,
        10000m, null, null, "2024-01-01", null, "Cancelled", null,
        DateTime.UtcNow, DateTime.UtcNow);

    public CancelTransactionCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Transactions).Returns(_transactions.Object);
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

        _handler = new CancelTransactionCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBus.Object, _logger.Object);
    }

    private TxEntity CreatePendingSubscription()
        => TxEntity.CreateSubscription(
            TenantId, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));

    [Fact]
    public async Task Handle_WithPendingTransaction_CancelsAndPublishesEvent()
    {
        var tx = CreatePendingSubscription();
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);
        _mapper.Setup(m => m.Map<TransactionDto>(tx)).Returns(MakeDto());

        var result = await _handler.Handle(new CancelTransactionCommand(tx.Id, "Test reason"), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _eventBus.Verify(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new CancelTransactionCommand(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WhenTransactionNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _transactions.Setup(r => r.GetByIdAsync(missingId, It.IsAny<CancellationToken>())).ReturnsAsync((TxEntity?)null);

        var result = await _handler.Handle(new CancelTransactionCommand(missingId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenTransactionBelongsToDifferentTenant_ReturnsFailure()
    {
        var tx = TxEntity.CreateSubscription(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);

        var result = await _handler.Handle(new CancelTransactionCommand(tx.Id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenTransactionAlreadySettled_ReturnsFailure()
    {
        var tx = CreatePendingSubscription();
        tx.Process(10m);
        tx.Settle(DateOnly.FromDateTime(DateTime.UtcNow));
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);

        var result = await _handler.Handle(new CancelTransactionCommand(tx.Id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        _eventBus.Verify(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}

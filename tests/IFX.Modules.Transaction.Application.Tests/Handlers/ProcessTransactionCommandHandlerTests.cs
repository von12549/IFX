using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Transaction.Application.Commands.ProcessTransaction;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class ProcessTransactionCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<ITransactionRepository> _transactions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<ProcessTransactionCommandHandler>> _logger = new();
    private readonly ProcessTransactionCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    private static TransactionDto MakeDto() => new(
        Guid.NewGuid(), Guid.NewGuid(), "Subscription",
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), null,
        10000m, 1000m, 10m, "2024-01-01", null, "Processed", null,
        DateTime.UtcNow, DateTime.UtcNow);

    public ProcessTransactionCommandHandlerTests()
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

        _handler = new ProcessTransactionCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    private TxEntity CreatePendingSubscription()
    {
        return TxEntity.CreateSubscription(
            TenantId, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));
    }

    [Fact]
    public async Task Handle_WithPendingTransaction_ProcessesAndPublishesEvent()
    {
        var tx = CreatePendingSubscription();
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);
        _mapper.Setup(m => m.Map<TransactionDto>(tx)).Returns(MakeDto());

        var result = await _handler.Handle(new ProcessTransactionCommand(tx.Id, 10m), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        tx.NAVPrice.Should().Be(10m);
        tx.Units.Should().Be(1000m);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Verify(e => e.Add(It.IsAny<IIntegrationEvent>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenTransactionNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _transactions.Setup(r => r.GetByIdAsync(missingId, It.IsAny<CancellationToken>())).ReturnsAsync((TxEntity?)null);

        var result = await _handler.Handle(new ProcessTransactionCommand(missingId, 10m), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenTransactionBelongsToDifferentTenant_ReturnsFailure()
    {
        var tx = TxEntity.CreateSubscription(
            Guid.NewGuid(), // different tenant
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);

        var result = await _handler.Handle(new ProcessTransactionCommand(tx.Id, 10m), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new ProcessTransactionCommand(Guid.NewGuid(), 10m), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WhenTransactionAlreadyProcessed_ReturnsFailure()
    {
        var tx = CreatePendingSubscription();
        tx.Process(5m); // already processed
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);

        var result = await _handler.Handle(new ProcessTransactionCommand(tx.Id, 10m), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        _eventBuffer.Verify(e => e.Add(It.IsAny<IIntegrationEvent>()), Times.Never);
    }
}

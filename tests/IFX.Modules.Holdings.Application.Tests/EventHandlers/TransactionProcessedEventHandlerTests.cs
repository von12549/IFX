using IFX.Modules.Holdings.Application.EventHandlers;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Transaction.Abstractions.Events;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.EventHandlers;

public class TransactionProcessedEventHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<ILogger<TransactionProcessedEventHandler>> _logger = new();
    private readonly TransactionProcessedEventHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public TransactionProcessedEventHandlerTests()
    {
        _unitOfWork.Setup(u => u.Holdings).Returns(_holdings.Object);
        _unitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        _handler = new TransactionProcessedEventHandler(_unitOfWork.Object, _logger.Object);
    }

    [Fact]
    public async Task HandleAsync_Subscription_CreatesHoldingAndAppliesUnits()
    {
        var investorId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        _holdings.Setup(r => r.GetByInvestorAndClassAsync(TenantId, investorId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Holding?)null);

        Holding? added = null;
        _holdings.Setup(r => r.AddAsync(It.IsAny<Holding>(), It.IsAny<CancellationToken>()))
            .Callback<Holding, CancellationToken>((h, _) => added = h)
            .Returns(Task.CompletedTask);

        var @event = new TransactionProcessedEvent(
            Guid.NewGuid(), TenantId, "Subscription", investorId, classId, null, 100m, 10m);

        await _handler.HandleAsync(@event);

        added.Should().NotBeNull();
        added!.Units.Should().Be(100m);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task HandleAsync_Subscription_UpdatesExistingHolding()
    {
        var investorId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        var existing = Holding.Create(TenantId, investorId, classId);
        existing.ApplySubscription(50m);

        _holdings.Setup(r => r.GetByInvestorAndClassAsync(TenantId, investorId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        var @event = new TransactionProcessedEvent(
            Guid.NewGuid(), TenantId, "Subscription", investorId, classId, null, 100m, 10m);

        await _handler.HandleAsync(@event);

        existing.Units.Should().Be(150m);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task HandleAsync_Redemption_ReducesHoldingUnits()
    {
        var investorId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        var existing = Holding.Create(TenantId, investorId, classId);
        existing.ApplySubscription(200m);

        _holdings.Setup(r => r.GetByInvestorAndClassAsync(TenantId, investorId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        var @event = new TransactionProcessedEvent(
            Guid.NewGuid(), TenantId, "Redemption", investorId, classId, null, 50m, 10m);

        await _handler.HandleAsync(@event);

        existing.Units.Should().Be(150m);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task HandleAsync_Redemption_WhenNoHoldingExists_DoesNotThrow()
    {
        var investorId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        _holdings.Setup(r => r.GetByInvestorAndClassAsync(TenantId, investorId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Holding?)null);

        var @event = new TransactionProcessedEvent(
            Guid.NewGuid(), TenantId, "Redemption", investorId, classId, null, 50m, 10m);

        await _handler.Invoking(h => h.HandleAsync(@event)).Should().NotThrowAsync();
    }

    [Fact]
    public async Task HandleAsync_Transfer_DecrementsSourceAndIncrementsTarget()
    {
        var investorId = Guid.NewGuid();
        var sourceClassId = Guid.NewGuid();
        var targetClassId = Guid.NewGuid();

        var sourceHolding = Holding.Create(TenantId, investorId, sourceClassId);
        sourceHolding.ApplySubscription(300m);

        _holdings.Setup(r => r.GetByInvestorAndClassAsync(TenantId, investorId, sourceClassId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(sourceHolding);
        _holdings.Setup(r => r.GetByInvestorAndClassAsync(TenantId, investorId, targetClassId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Holding?)null);

        Holding? targetAdded = null;
        _holdings.Setup(r => r.AddAsync(It.IsAny<Holding>(), It.IsAny<CancellationToken>()))
            .Callback<Holding, CancellationToken>((h, _) => targetAdded = h)
            .Returns(Task.CompletedTask);

        var @event = new TransactionProcessedEvent(
            Guid.NewGuid(), TenantId, "Transfer", investorId, sourceClassId, targetClassId, 100m, 10m);

        await _handler.HandleAsync(@event);

        sourceHolding.Units.Should().Be(200m);
        targetAdded.Should().NotBeNull();
        targetAdded!.Units.Should().Be(100m);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}

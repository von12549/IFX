using IFX.Modules.Holdings.Application.EventHandlers;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Enums;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Registry.Abstractions.Events;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.EventHandlers;

public class ClassStatusChangedEventHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<ILogger<ClassStatusChangedEventHandler>> _logger = new();
    private readonly ClassStatusChangedEventHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public ClassStatusChangedEventHandlerTests()
    {
        _unitOfWork.Setup(u => u.Holdings).Returns(_holdings.Object);
        _unitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        _handler = new ClassStatusChangedEventHandler(_unitOfWork.Object, _logger.Object);
    }

    [Fact]
    public async Task HandleAsync_WhenClassClosed_FreezesAllHoldings()
    {
        var classId = Guid.NewGuid();
        var h1 = Holding.Create(TenantId, Guid.NewGuid(), classId);
        h1.ApplySubscription(100m);
        var h2 = Holding.Create(TenantId, Guid.NewGuid(), classId);
        h2.ApplySubscription(200m);

        _holdings.Setup(r => r.GetByClassAsync(TenantId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding> { h1, h2 });

        var @event = new ClassStatusChangedEvent(classId, Guid.NewGuid(), TenantId, "Active", "Closed");

        await _handler.HandleAsync(@event);

        h1.Status.Should().Be(HoldingStatus.Frozen);
        h2.Status.Should().Be(HoldingStatus.Frozen);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task HandleAsync_WhenClassLiquidating_FreezesAllHoldings()
    {
        var classId = Guid.NewGuid();
        var holding = Holding.Create(TenantId, Guid.NewGuid(), classId);
        holding.ApplySubscription(50m);

        _holdings.Setup(r => r.GetByClassAsync(TenantId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding> { holding });

        var @event = new ClassStatusChangedEvent(classId, Guid.NewGuid(), TenantId, "Active", "Liquidating");

        await _handler.HandleAsync(@event);

        holding.Status.Should().Be(HoldingStatus.Frozen);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task HandleAsync_WhenClassNotClosedOrLiquidating_DoesNotFreezeHoldings()
    {
        var classId = Guid.NewGuid();
        var @event = new ClassStatusChangedEvent(classId, Guid.NewGuid(), TenantId, "Active", "Suspended");

        await _handler.HandleAsync(@event);

        _holdings.Verify(r => r.GetByClassAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task HandleAsync_WhenNoHoldingsForClass_SavesWithoutError()
    {
        var classId = Guid.NewGuid();
        _holdings.Setup(r => r.GetByClassAsync(TenantId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding>());

        var @event = new ClassStatusChangedEvent(classId, Guid.NewGuid(), TenantId, "Active", "Closed");

        await _handler.Invoking(h => h.HandleAsync(@event)).Should().NotThrowAsync();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}

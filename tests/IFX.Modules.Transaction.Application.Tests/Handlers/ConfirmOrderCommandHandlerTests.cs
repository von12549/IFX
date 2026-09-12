using IFX.Modules.Transaction.Application.Ports.Authorization;
using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.Transaction.Application.Commands.ConfirmOrder;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Entities;
using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Modules.Transaction.Contracts.V1.Events;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class ConfirmOrderCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IOrderRepository> _orders = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<ConfirmOrderCommandHandler>> _logger = new();
    private readonly ConfirmOrderCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateOnly TradeDate = DateOnly.FromDateTime(DateTime.UtcNow);

    private Order CreateAcceptedOrder()
    {
        var order = Order.CreateSubscriptionOrder(TenantId, "ORD-001", Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 10000m, "AUD", TradeDate);
        order.Accept("DEAL-001");
        return order;
    }

    public ConfirmOrderCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Orders).Returns(_orders.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _mapper.Setup(m => m.Map<OrderDto>(It.IsAny<Order>())).Returns(
            new OrderDto(Guid.NewGuid(), TenantId, "SubscriptionOrder", "ORD-001", "DEAL-001", "PriceConfirmed",
                null, null, null, Array.Empty<OrderLegDto>(), DateTime.UtcNow, DateTime.UtcNow));

        _handler = new ConfirmOrderCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithAcceptedOrder_ConfirmsLegsAndPublishesEvents()
    {
        var order = CreateAcceptedOrder();
        var legId = order.Legs[0].Id;
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);

        var legs = new List<OrderLegConfirmation>
        {
            new(legId, 10m, 1000m, "NAVL", null)
        };

        var result = await _handler.Handle(new ConfirmOrderCommand(order.Id, legs), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        order.Status.Should().Be(Domain.Enums.OrderStatus.PriceConfirmed);
        order.Legs[0].NAVPrice.Should().Be(10m);
        order.Legs[0].Units.Should().Be(1000m);
        _eventBuffer.Verify(e => e.Add(It.IsAny<TransactionProcessedV1>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenOrderNotFound_ReturnsFailure()
    {
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Order?)null);

        var result = await _handler.Handle(new ConfirmOrderCommand(Guid.NewGuid(), []), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenOrderNotYetAccepted_ReturnsFailure()
    {
        var order = Order.CreateSubscriptionOrder(TenantId, "ORD-001", Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 10000m, "AUD", TradeDate);
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);

        var result = await _handler.Handle(new ConfirmOrderCommand(order.Id, []), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenLegNotFoundOnOrder_ReturnsFailure()
    {
        var order = CreateAcceptedOrder();
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);

        var legs = new List<OrderLegConfirmation> { new(Guid.NewGuid(), 10m, 1000m, null, null) };

        var result = await _handler.Handle(new ConfirmOrderCommand(order.Id, legs), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

using IFX.Modules.Transaction.Application.Ports.Authorization;
using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.Transaction.Application.Commands.AcceptOrder;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Entities;
using IFX.Modules.Transaction.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class AcceptOrderCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IOrderRepository> _orders = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<AcceptOrderCommandHandler>> _logger = new();
    private readonly AcceptOrderCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateOnly TradeDate = DateOnly.FromDateTime(DateTime.UtcNow);

    private static OrderDto MakeOrderDto(string status = "Accepted") => new(
        Guid.NewGuid(), TenantId, "SubscriptionOrder", "ORD-001", "DEAL-001", status,
        null, null, null, Array.Empty<OrderLegDto>(), DateTime.UtcNow, DateTime.UtcNow);

    private Order CreateSubmittedOrder() =>
        Order.CreateSubscriptionOrder(TenantId, "ORD-001", Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 10000m, "AUD", TradeDate);

    public AcceptOrderCommandHandlerTests()
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
        _mapper.Setup(m => m.Map<OrderDto>(It.IsAny<Order>())).Returns(MakeOrderDto());

        _handler = new AcceptOrderCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithSubmittedOrder_AcceptsAndPublishesEvent()
    {
        var order = CreateSubmittedOrder();
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);

        var result = await _handler.Handle(new AcceptOrderCommand(order.Id, "DEAL-001", null, null), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        order.Status.Should().Be(Domain.Enums.OrderStatus.Accepted);
        order.DealReference.Should().Be("DEAL-001");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenOrderNotFound_ReturnsFailure()
    {
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Order?)null);

        var result = await _handler.Handle(new AcceptOrderCommand(Guid.NewGuid(), "DEAL-001", null, null), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenOrderBelongsToDifferentTenant_ReturnsFailure()
    {
        var order = Order.CreateSubscriptionOrder(Guid.NewGuid(), "ORD-001", Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 10000m, "AUD", TradeDate);
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);

        var result = await _handler.Handle(new AcceptOrderCommand(order.Id, "DEAL-001", null, null), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenOrderAlreadyAccepted_ReturnsFailure()
    {
        var order = CreateSubmittedOrder();
        order.Accept("DEAL-ORIGINAL");
        _orders.Setup(r => r.GetByIdWithLegsAsync(TenantId, order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);

        var result = await _handler.Handle(new AcceptOrderCommand(order.Id, "DEAL-NEW", null, null), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new AcceptOrderCommand(Guid.NewGuid(), "DEAL-001", null, null), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}

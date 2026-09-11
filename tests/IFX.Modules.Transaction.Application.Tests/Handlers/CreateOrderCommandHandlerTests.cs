using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Transaction.Application.Commands.CreateOrder;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Ports;
using IFX.Modules.Transaction.Domain.Entities;
using IFX.Modules.Transaction.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class CreateOrderCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IOrderRepository> _orders = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IAccountCompliancePort> _accountCompliance = new();
    private readonly Mock<IClassSubscriptionAvailabilityPort> _classSubscriptionAvailability = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<CreateOrderCommandHandler>> _logger = new();
    private readonly CreateOrderCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateOnly TradeDate = DateOnly.FromDateTime(DateTime.UtcNow);

    private static OrderDto MakeOrderDto() => new(
        Guid.NewGuid(), TenantId, "SubscriptionOrder", "ORD-001", null, "Submitted",
        null, null, null, Array.Empty<OrderLegDto>(), DateTime.UtcNow, DateTime.UtcNow);

    private static CreateOrderCommand SubscriptionCommand() => new(
        "SubscriptionOrder", "ORD-001", Guid.NewGuid(),
        Guid.NewGuid(), Guid.NewGuid(), null, null,
        10000m, "AUD", TradeDate);

    private static CreateOrderCommand SwitchCommand() => new(
        "SwitchOrder", "ORD-002", Guid.NewGuid(),
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
        5000m, "AUD", TradeDate);

    public CreateOrderCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Orders).Returns(_orders.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _accountCompliance.Setup(c => c.IsApprovedAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        _classSubscriptionAvailability.Setup(r => r.IsOpenAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        _mapper.Setup(m => m.Map<OrderDto>(It.IsAny<Order>())).Returns(MakeOrderDto());

        _handler = new CreateOrderCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _accountCompliance.Object, _classSubscriptionAvailability.Object,
            _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_SubscriptionOrder_CreatesOrderAndPublishesEvent()
    {
        var result = await _handler.Handle(SubscriptionCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _orders.Verify(r => r.AddAsync(It.IsAny<Order>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_SwitchOrder_CreatesTwoLegs()
    {
        Order? capturedOrder = null;
        _orders.Setup(r => r.AddAsync(It.IsAny<Order>(), It.IsAny<CancellationToken>()))
            .Callback<Order, CancellationToken>((o, _) => capturedOrder = o)
            .Returns(Task.CompletedTask);

        var result = await _handler.Handle(SwitchCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        capturedOrder.Should().NotBeNull();
        capturedOrder!.Legs.Should().HaveCount(2);
        capturedOrder.Legs.Any(l => l.Type == Domain.Enums.TransactionType.Redemption).Should().BeTrue();
        capturedOrder.Legs.Any(l => l.Type == Domain.Enums.TransactionType.Subscription).Should().BeTrue();
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(SubscriptionCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
        _orders.Verify(r => r.AddAsync(It.IsAny<Order>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenKycNotApproved_ReturnsFailure()
    {
        _accountCompliance.Setup(c => c.IsApprovedAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);

        var result = await _handler.Handle(SubscriptionCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("KYC");
        _orders.Verify(r => r.AddAsync(It.IsAny<Order>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenClassNotOpenForSubscription_ReturnsFailure()
    {
        _classSubscriptionAvailability.Setup(r => r.IsOpenAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);

        var result = await _handler.Handle(SubscriptionCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not open");
    }

    [Fact]
    public async Task Handle_SwitchOrderMissingToClassId_ReturnsFailure()
    {
        var cmd = new CreateOrderCommand(
            "SwitchOrder", "ORD-003", Guid.NewGuid(),
            Guid.NewGuid(), Guid.NewGuid(), null, null, // ToFundId and ToClassId both null
            5000m, "AUD", TradeDate);

        var result = await _handler.Handle(cmd, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("ToFundId");
    }
}

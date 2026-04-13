using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Queries.GetTransactionById;
using IFX.Modules.Transaction.Domain.Repositories;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class GetTransactionByIdQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<ITransactionRepository> _transactions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<GetTransactionByIdQueryHandler>> _logger = new();
    private readonly GetTransactionByIdQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    private static TransactionDto MakeDto() => new(
        Guid.NewGuid(), Guid.NewGuid(), "Subscription",
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), null,
        10000m, null, null, "2024-01-01", null, "Pending", null,
        DateTime.UtcNow, DateTime.UtcNow);

    public GetTransactionByIdQueryHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Transactions).Returns(_transactions.Object);

        _handler = new GetTransactionByIdQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenTransactionExists_ReturnsDto()
    {
        var tx = TxEntity.CreateSubscription(
            TenantId, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);
        _mapper.Setup(m => m.Map<TransactionDto>(tx)).Returns(MakeDto());

        var result = await _handler.Handle(new GetTransactionByIdQuery(tx.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().NotBeNull();
    }

    [Fact]
    public async Task Handle_WhenTransactionNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _transactions.Setup(r => r.GetByIdAsync(missingId, It.IsAny<CancellationToken>())).ReturnsAsync((TxEntity?)null);

        var result = await _handler.Handle(new GetTransactionByIdQuery(missingId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenTransactionBelongsToDifferentTenant_ReturnsFailure()
    {
        var tx = TxEntity.CreateSubscription(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));
        _transactions.Setup(r => r.GetByIdAsync(tx.Id, It.IsAny<CancellationToken>())).ReturnsAsync(tx);

        var result = await _handler.Handle(new GetTransactionByIdQuery(tx.Id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetTransactionByIdQuery(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}

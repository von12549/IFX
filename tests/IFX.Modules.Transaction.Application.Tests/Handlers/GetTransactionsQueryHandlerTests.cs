using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Queries.GetTransactions;
using IFX.Modules.Transaction.Domain.Repositories;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Tests.Handlers;

public class GetTransactionsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<ITransactionRepository> _transactions = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<ILogger<GetTransactionsQueryHandler>> _logger = new();
    private readonly GetTransactionsQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    private static TransactionDto MakeDto() => new(
        Guid.NewGuid(), Guid.NewGuid(), "Subscription",
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), null,
        10000m, null, null, "2024-01-01", null, "Pending", null,
        DateTime.UtcNow, DateTime.UtcNow);

    public GetTransactionsQueryHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Transactions).Returns(_transactions.Object);

        _handler = new GetTransactionsQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithTenantContext_ReturnsTransactions()
    {
        var tx = TxEntity.CreateSubscription(
            TenantId, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10000m, DateOnly.FromDateTime(DateTime.UtcNow));
        _transactions.Setup(r => r.GetByTenantAsync(TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<TxEntity> { tx });
        _mapper.Setup(m => m.Map<TransactionDto>(tx)).Returns(MakeDto());

        var result = await _handler.Handle(new GetTransactionsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetTransactionsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WhenNoTransactions_ReturnsEmptyList()
    {
        _transactions.Setup(r => r.GetByTenantAsync(TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<TxEntity>());

        var result = await _handler.Handle(new GetTransactionsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}

using IFX.Modules.Transaction.Abstractions.DTOs;
using IFX.Modules.Transaction.Abstractions.Interfaces;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Transaction.Infrastructure.Services;

public class TransactionReader : ITransactionReader
{
    private readonly TransactionDbContext _context;

    public TransactionReader(TransactionDbContext context) => _context = context;

    public async Task<TransactionSummaryDto?> GetTransactionByIdAsync(Guid transactionId, CancellationToken ct = default)
    {
        var tx = await _context.Transactions.FirstOrDefaultAsync(t => t.Id == transactionId, ct);
        if (tx == null) return null;
        return new TransactionSummaryDto(tx.Id, tx.TenantId, tx.Type.ToString(), tx.InvestmentAccountId, tx.ClassId, tx.Amount, tx.Status.ToString());
    }

    public async Task<OrderSummaryDto?> GetOrderByIdAsync(Guid orderId, CancellationToken ct = default)
    {
        var order = await _context.Orders
            .Include(o => o.Legs)
            .FirstOrDefaultAsync(o => o.Id == orderId, ct);
        if (order == null) return null;
        return new OrderSummaryDto(order.Id, order.TenantId, order.OrderType.ToString(),
            order.OrderReference, order.DealReference, order.Status.ToString(), order.Legs.Count, order.CreatedAt);
    }

    public async Task<IReadOnlyList<OrderSummaryDto>> GetOrdersByInvestmentAccountAsync(
        Guid tenantId, Guid investmentAccountId, CancellationToken ct = default)
    {
        var orders = await _context.Orders
            .Include(o => o.Legs)
            .Where(o => o.TenantId == tenantId && o.Legs.Any(l => l.InvestmentAccountId == investmentAccountId))
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(ct);

        return orders.Select(o => new OrderSummaryDto(
            o.Id, o.TenantId, o.OrderType.ToString(),
            o.OrderReference, o.DealReference, o.Status.ToString(), o.Legs.Count, o.CreatedAt)).ToList();
    }
}

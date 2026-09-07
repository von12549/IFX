using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Domain.Repositories;

namespace IFX.Modules.Holdings.Infrastructure.Persistence;

public class HoldingsUnitOfWork : IUnitOfWork
{
    private readonly HoldingsDbContext _context;

    public HoldingsUnitOfWork(HoldingsDbContext context, IHoldingRepository holdings)
    {
        _context = context;
        Holdings = holdings;
    }

    public IHoldingRepository Holdings { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        => await _context.SaveChangesAsync(cancellationToken);

    public void Dispose() => _context.Dispose();
}

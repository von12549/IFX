using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Repositories;

namespace IFX.Modules.Registry.Infrastructure.Persistence;

public class RegistryUnitOfWork : IUnitOfWork
{
    private readonly RegistryDbContext _context;

    public RegistryUnitOfWork(
        RegistryDbContext context,
        IProductRepository products,
        IFundRepository funds,
        IFundClassRepository fundClasses)
    {
        _context = context;
        Products = products;
        Funds = funds;
        FundClasses = fundClasses;
    }

    public IProductRepository Products { get; }
    public IFundRepository Funds { get; }
    public IFundClassRepository FundClasses { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    public void Dispose()
    {
        _context.Dispose();
    }
}

using IFX.Modules.Registry.Domain.Repositories;


namespace IFX.Modules.Registry.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IProductRepository Products { get; }
    IFundRepository Funds { get; }
    IFundClassRepository FundClasses { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}

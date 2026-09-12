using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.IAM.Application.Transactions;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using System.Data;

namespace IFX.Modules.IAM.Infrastructure.Persistence;

public sealed class IamTransactionExecutor : EfCoreTransactionExecutor<IamTransactionOwner, IfxDbContext>
{
    private readonly IfxDbContext _context;
    public IamTransactionExecutor(IfxDbContext dbContext, ILogger<IamTransactionExecutor> logger) : base(dbContext, logger) => _context = dbContext;
    protected override Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken ct) =>
        _context.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
}

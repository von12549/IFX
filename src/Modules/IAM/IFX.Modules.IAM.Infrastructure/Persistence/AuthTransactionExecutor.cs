using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.IAM.Application.Transactions;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using System.Data;

namespace IFX.Modules.IAM.Infrastructure.Persistence;

public sealed class AuthTransactionExecutor(
    IfxDbContext dbContext,
    ILogger<AuthTransactionExecutor> logger)
    : EfCoreTransactionExecutor<AuthTransactionOwner, IfxDbContext>(dbContext, logger)
{
    protected override Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken ct) =>
        dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
}

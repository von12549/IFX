using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.Transaction.Application.Transactions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Infrastructure.Persistence;

public sealed class TransactionModuleExecutor(
    TransactionDbContext dbContext,
    ILogger<TransactionModuleExecutor> logger)
    : EfCoreTransactionExecutor<TransactionModuleOwner, TransactionDbContext>(dbContext, logger);

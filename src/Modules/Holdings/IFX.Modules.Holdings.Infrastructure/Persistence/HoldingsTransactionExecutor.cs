using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.Holdings.Application.Transactions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Infrastructure.Persistence;

public sealed class HoldingsTransactionExecutor(
    HoldingsDbContext dbContext,
    ILogger<HoldingsTransactionExecutor> logger)
    : EfCoreTransactionExecutor<HoldingsTransactionOwner, HoldingsDbContext>(dbContext, logger);

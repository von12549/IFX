using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.IAM.Application.Transactions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Infrastructure.Persistence;

public sealed class AuthTransactionExecutor(
    IfxDbContext dbContext,
    ILogger<AuthTransactionExecutor> logger)
    : EfCoreTransactionExecutor<AuthTransactionOwner, IfxDbContext>(dbContext, logger);

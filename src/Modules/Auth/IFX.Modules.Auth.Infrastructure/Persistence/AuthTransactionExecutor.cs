using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.Auth.Application.Transactions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Infrastructure.Persistence;

public sealed class AuthTransactionExecutor(
    IfxDbContext dbContext,
    ILogger<AuthTransactionExecutor> logger)
    : EfCoreTransactionExecutor<AuthTransactionOwner, IfxDbContext>(dbContext, logger);

using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.CRM.Application.Transactions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Infrastructure.Persistence;

public sealed class CrmTransactionExecutor(
    CrmDbContext dbContext,
    ILogger<CrmTransactionExecutor> logger)
    : EfCoreTransactionExecutor<CrmTransactionOwner, CrmDbContext>(dbContext, logger);

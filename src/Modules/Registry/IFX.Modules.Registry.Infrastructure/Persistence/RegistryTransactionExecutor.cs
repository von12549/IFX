using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using IFX.Modules.Registry.Application.Transactions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Infrastructure.Persistence;

public sealed class RegistryTransactionExecutor(
    RegistryDbContext dbContext,
    ILogger<RegistryTransactionExecutor> logger)
    : EfCoreTransactionExecutor<RegistryTransactionOwner, RegistryDbContext>(dbContext, logger);

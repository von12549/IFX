using IFX.Modules.Holdings.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Behaviors;

public class TransactionBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<TransactionBehavior<TRequest, TResponse>> _logger;

    public TransactionBehavior(
        IUnitOfWork unitOfWork,
        ILogger<TransactionBehavior<TRequest, TResponse>> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var requestName = typeof(TRequest).Name;

        // Only wrap commands in transactions (not queries)
        if (!requestName.EndsWith("Command"))
        {
            return await next();
        }

        _logger.LogInformation("Beginning transaction for {RequestName}", requestName);

        try
        {
            await _unitOfWork.BeginTransactionAsync(cancellationToken);

            var response = await next();

            await _unitOfWork.CommitTransactionAsync(cancellationToken);

            _logger.LogInformation("Committed transaction for {RequestName}", requestName);

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in transaction for {RequestName}, rolling back", requestName);

            await _unitOfWork.RollbackTransactionAsync(cancellationToken);

            throw;
        }
    }
}

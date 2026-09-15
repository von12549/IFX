using IFX.Platform.Context.Runtime.Outbound;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound;

internal static class FailClosedContractCall
{
    public static async Task<bool> ExecuteAsync<TContractException>(
        Func<CancellationToken, Task<bool>> operation,
        CancellationToken cancellationToken)
        where TContractException : Exception
    {
        try
        {
            return await operation(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (TimeoutException)
        {
            return false;
        }
        catch (OutboundContractContextException)
        {
            return false;
        }
        catch (Exception exception) when (exception is TContractException)
        {
            return false;
        }
    }
}

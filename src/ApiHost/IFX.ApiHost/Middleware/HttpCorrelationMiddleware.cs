using System.Net;
using IFX.ApiHost.Runtime;
using Microsoft.Extensions.Options;

namespace IFX.ApiHost.Middleware;

public sealed class HttpCorrelationMiddleware(
    RequestDelegate next,
    IOptions<HttpContextBoundaryOptions> options)
{
    public const string CorrelationHeader = "X-Correlation-Id";
    public const string ClientRequestHeader = "X-Client-Request-Id";
    internal const string CorrelationItemKey = "IFX.CorrelationId";
    internal const string ClientRequestItemKey = "IFX.ClientRequestId";

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = ResolveCorrelation(context, options.Value);
        context.Items[CorrelationItemKey] = correlationId;

        var clientRequestIds = context.Request.Headers.GetCommaSeparatedValues(ClientRequestHeader);
        if (clientRequestIds.Length == 1 && IsValidClientRequestId(clientRequestIds[0]))
        {
            context.Items[ClientRequestItemKey] = clientRequestIds[0];
        }

        context.Response.OnStarting(() =>
        {
            context.Response.Headers[CorrelationHeader] = correlationId.ToString("D");
            return Task.CompletedTask;
        });

        await next(context);
    }

    internal static Guid GetCorrelation(HttpContext context) =>
        context.Items.TryGetValue(CorrelationItemKey, out var value) && value is Guid correlationId
            ? correlationId
            : Guid.NewGuid();

    private static Guid ResolveCorrelation(
        HttpContext context,
        HttpContextBoundaryOptions boundaryOptions)
    {
        if (!boundaryOptions.AllowTrustedGatewayCorrelationPropagation ||
            !IsTrustedGateway(context.Connection.RemoteIpAddress, boundaryOptions.TrustedGatewayAddresses))
        {
            return Guid.NewGuid();
        }

        var propagated = context.Request.Headers.GetCommaSeparatedValues(CorrelationHeader);
        return propagated.Length == 1 && Guid.TryParseExact(propagated[0], "D", out var correlationId) && correlationId != Guid.Empty
            ? correlationId
            : Guid.NewGuid();
    }

    private static bool IsTrustedGateway(IPAddress? remoteAddress, IEnumerable<string> trustedAddresses)
    {
        if (remoteAddress is null)
        {
            return false;
        }

        var normalizedRemote = remoteAddress.IsIPv4MappedToIPv6
            ? remoteAddress.MapToIPv4()
            : remoteAddress;
        return trustedAddresses.Any(value =>
            IPAddress.TryParse(value, out var trusted) &&
            normalizedRemote.Equals(trusted.IsIPv4MappedToIPv6 ? trusted.MapToIPv4() : trusted));
    }

    private static bool IsValidClientRequestId(string value) =>
        value.Length is > 0 and <= 64 &&
        value.All(character => char.IsAsciiLetterOrDigit(character) || character is '.' or '_' or '-');
}

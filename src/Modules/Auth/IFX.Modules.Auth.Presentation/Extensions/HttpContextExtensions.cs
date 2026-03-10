using Microsoft.AspNetCore.Http;

namespace IFX.Modules.Auth.Presentation.Extensions;

public static class HttpContextExtensions
{
    /// <summary>
    /// Get the IP address from the HTTP context
    /// </summary>
    /// <param name="context">The HTTP context</param>
    /// <returns>IP address string or "Unknown" if not available</returns>
    public static string GetIpAddress(this HttpContext context)
    {
        return context.Connection.RemoteIpAddress?.ToString() ?? "Unknown";
    }
}

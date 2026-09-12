using System.Net;
using IFX.Modules.IAM.Application.Ports.Authorization;
using Microsoft.AspNetCore.Http;

namespace IFX.Modules.IAM.Infrastructure.Access;

// Background execution has no network fact; it must never impersonate an internal HTTP request.
public sealed class AuthorizationEnvironment(IHttpContextAccessor context) : IAuthorizationEnvironmentPort
{
    public EnvironmentFacts GetFacts()
    {
        var ip = context.HttpContext?.Connection.RemoteIpAddress;
        var bytes = ip?.GetAddressBytes();
        var internalNetwork = ip is not null && (IPAddress.IsLoopback(ip) || bytes is { Length: 4 } &&
            (bytes[0] == 10 || bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31 || bytes[0] == 192 && bytes[1] == 168));
        return new(ip?.ToString(), ip is null ? null : internalNetwork ? "internal" : "external", DateTime.UtcNow.ToString("O"));
    }
}

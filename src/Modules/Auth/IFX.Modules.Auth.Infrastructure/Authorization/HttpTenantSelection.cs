using Microsoft.AspNetCore.Http;

namespace IFX.Modules.Auth.Infrastructure.Authorization;

public sealed class HttpTenantSelection(
    IHttpContextAccessor httpContextAccessor,
    HttpIdentityFacts identityFacts)
{
    public Guid? ResolveTenantId()
    {
        var headerValue = httpContextAccessor.HttpContext?.Request.Headers["X-Tenant-Id"].FirstOrDefault();
        if (Guid.TryParse(headerValue, out var headerId) && identityFacts.IsTenantMember(headerId))
        {
            return headerId;
        }

        // Compatibility behavior is isolated here. Phase 3 replaces this with fail-closed parsing.
        return identityFacts.PrimaryTenantId;
    }
}

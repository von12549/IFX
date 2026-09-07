using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;

namespace IFX.Modules.Auth.Application.Identity.Interfaces;

public interface IEmailVerificationIssuanceService
{
    Task<Result<EmailVerificationTokenInfo>> IssueAsync(
        Guid userIdentityId,
        string? ipAddress,
        CancellationToken cancellationToken);
}

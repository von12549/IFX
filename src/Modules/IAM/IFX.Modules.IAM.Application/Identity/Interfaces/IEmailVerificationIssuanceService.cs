using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;

namespace IFX.Modules.IAM.Application.Identity.Interfaces;

public interface IEmailVerificationIssuanceService
{
    Task<Result<EmailVerificationTokenInfo>> IssueAsync(
        Guid userIdentityId,
        string? ipAddress,
        CancellationToken cancellationToken);
}

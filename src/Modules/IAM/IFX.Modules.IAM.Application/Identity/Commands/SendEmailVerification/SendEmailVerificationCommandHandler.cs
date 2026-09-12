using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.SendEmailVerification;
public sealed class SendEmailVerificationCommandHandler(
    IEmailVerificationIssuanceService issuanceService)
    : IRequestHandler<SendEmailVerificationCommand, Result<EmailVerificationTokenInfo>>
{
    public Task<Result<EmailVerificationTokenInfo>> Handle(
        SendEmailVerificationCommand request,
        CancellationToken cancellationToken) =>
        issuanceService.IssueAsync(request.UserIdentityId, request.IpAddress, cancellationToken);
}

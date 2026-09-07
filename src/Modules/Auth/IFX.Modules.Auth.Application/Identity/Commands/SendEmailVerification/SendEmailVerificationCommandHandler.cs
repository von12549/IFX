using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.SendEmailVerification;
public sealed class SendEmailVerificationCommandHandler(
    IEmailVerificationIssuanceService issuanceService)
    : IRequestHandler<SendEmailVerificationCommand, Result<EmailVerificationTokenInfo>>
{
    public Task<Result<EmailVerificationTokenInfo>> Handle(
        SendEmailVerificationCommand request,
        CancellationToken cancellationToken) =>
        issuanceService.IssueAsync(request.UserIdentityId, request.IpAddress, cancellationToken);
}

using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.DeleteInvestmentAccount;
public class DeleteInvestmentAccountCommandHandler : IRequestHandler<DeleteInvestmentAccountCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<DeleteInvestmentAccountCommandHandler> _logger;
    public DeleteInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<DeleteInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<Unit>> Handle(DeleteInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investment-account", "delete", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            var account = await _unitOfWork.InvestmentAccounts.GetByIdAsync(request.Id, tenantId, cancellationToken);
            if (account == null)
                return Result<Unit>.Failure("Investment account not found.");
            account.Deactivate();
            account.UpdatedBy = _currentUser.UserId;
            _unitOfWork.InvestmentAccounts.Update(account);
            return Result<Unit>.Success(Unit.Value);
        }
    }
}

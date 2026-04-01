using IFX.BuildingBlocks.Security.Authorization.Abstractions;

using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Commands.DeleteInvestor;

public class DeleteInvestorCommandHandler : IRequestHandler<DeleteInvestorCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<DeleteInvestorCommandHandler> _logger;

    public DeleteInvestorCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<DeleteInvestorCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteInvestorCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<bool>.Failure("Tenant context is required.");

            var investor = await _unitOfWork.Investors.GetByIdAsync(request.InvestorId, _currentUser.TenantId.Value, cancellationToken);
            if (investor == null)
                return Result<bool>.Failure("Investor not found.");

            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "delete",
                resourceAttributes,
                ct: cancellationToken);

            investor.Close();
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Investor closed: {InvestorId}", request.InvestorId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error closing investor {InvestorId}", request.InvestorId);
            return Result<bool>.Failure("An error occurred while closing the investor.");
        }
    }
}

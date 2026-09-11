using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;
public class CreateInvestorCommandHandler : IRequestHandler<CreateInvestorCommand, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateInvestorCommandHandler> _logger;
    public CreateInvestorCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CreateInvestorCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(CreateInvestorCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investor", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<InvestorDto>.Failure("Tenant context is required.");
            if (await _unitOfWork.Investors.CodeExistsAsync(request.InvestorCode, _currentUser.TenantId.Value, cancellationToken))
                return Result<InvestorDto>.Failure($"Investor code '{request.InvestorCode}' already exists in this tenant.");
            var investor = Investor.Create(_currentUser.TenantId.Value, request.InvestorCode, request.Name, request.LegalStructure, request.TaxResidencyCountry, request.PartyId);
            investor.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Investors.AddAsync(investor, cancellationToken);
            _logger.LogInformation("Investor created: {InvestorCode} in tenant {TenantId}", investor.InvestorCode, investor.TenantId);
            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
    }
}

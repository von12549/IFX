using IFX.Modules.IAM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Commands.CreateDepartment;
public class CreateDepartmentCommandHandler : IRequestHandler<CreateDepartmentCommand, Result<DepartmentDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CreateDepartmentCommandHandler> _logger;
    public CreateDepartmentCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<CreateDepartmentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<DepartmentDto>> Handle(CreateDepartmentCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("department", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<DepartmentDto>.Failure("Tenant not found");
            if (await _unitOfWork.Departments.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<DepartmentDto>.Failure($"Department '{request.Name}' already exists in this tenant");
            var department = Department.Create(request.Name, request.Description, request.TenantId);
            department.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Departments.AddAsync(department, cancellationToken);
            _logger.LogInformation("Department created: {Name} in tenant {TenantId}", request.Name, request.TenantId);
            return Result<DepartmentDto>.Success(_mapper.Map<DepartmentDto>(department));
        }
    }
}

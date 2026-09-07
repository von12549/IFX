using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Departments.Authorization;
using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.UpdateDepartment;
public class UpdateDepartmentCommandHandler : IRequestHandler<UpdateDepartmentCommand, Result<DepartmentDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateDepartmentCommandHandler> _logger;
    public UpdateDepartmentCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, IResourceAuthorizationService authorizationService, ILogger<UpdateDepartmentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<DepartmentDto>> Handle(UpdateDepartmentCommand request, CancellationToken cancellationToken)
    {
        {
            var department = await _unitOfWork.Departments.GetByIdAsync(request.DepartmentId, cancellationToken);
            if (department == null)
                return Result<DepartmentDto>.Failure("Department not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("department", "update", new DepartmentResourceAttributes(department.Id, department.TenantId, department.CreatedBy), ct: cancellationToken);
            if (department.Name != request.Name && await _unitOfWork.Departments.NameExistsAsync(request.Name, department.TenantId, request.DepartmentId, cancellationToken))
                return Result<DepartmentDto>.Failure($"Department '{request.Name}' already exists in this tenant");
            department.Update(request.Name, request.Description);
            _logger.LogInformation("Department {DepartmentId} updated: {Name}", request.DepartmentId, request.Name);
            return Result<DepartmentDto>.Success(_mapper.Map<DepartmentDto>(department));
        }
    }
}

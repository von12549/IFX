using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.CreateDepartment;

public class CreateDepartmentCommandHandler : IRequestHandler<CreateDepartmentCommand, Result<DepartmentDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<CreateDepartmentCommandHandler> _logger;

    public CreateDepartmentCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<CreateDepartmentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<DepartmentDto>> Handle(CreateDepartmentCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<DepartmentDto>.Failure("Tenant not found");

            if (await _unitOfWork.Departments.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<DepartmentDto>.Failure($"Department '{request.Name}' already exists in this tenant");

            var department = Department.Create(request.Name, request.Description, request.TenantId);
            await _unitOfWork.Departments.AddAsync(department, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Department created: {Name} in tenant {TenantId}", request.Name, request.TenantId);
            return Result<DepartmentDto>.Success(_mapper.Map<DepartmentDto>(department));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating department {Name}", request.Name);
            return Result<DepartmentDto>.Failure("An error occurred while creating the department");
        }
    }
}

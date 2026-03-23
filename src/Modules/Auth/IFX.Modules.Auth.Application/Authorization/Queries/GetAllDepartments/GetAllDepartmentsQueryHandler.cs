using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllDepartments;

public class GetAllDepartmentsQueryHandler : IRequestHandler<GetAllDepartmentsQuery, Result<List<DepartmentDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetAllDepartmentsQueryHandler> _logger;

    public GetAllDepartmentsQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, ILogger<GetAllDepartmentsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<List<DepartmentDto>>> Handle(GetAllDepartmentsQuery request, CancellationToken cancellationToken)
    {
        if (!_currentUser.TenantId.HasValue)
            return Result<List<DepartmentDto>>.Success([]);

        var departments = await _unitOfWork.Departments.GetByTenantIdAsync(_currentUser.TenantId.Value, cancellationToken);

        return Result<List<DepartmentDto>>.Success(_mapper.Map<List<DepartmentDto>>(departments));
    }
}

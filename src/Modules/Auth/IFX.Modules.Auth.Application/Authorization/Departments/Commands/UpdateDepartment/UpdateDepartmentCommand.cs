using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.UpdateDepartment;

public record UpdateDepartmentCommand(Guid DepartmentId, string Name, string Description) : ICommand<Result<DepartmentDto>, AuthTransactionOwner>;

using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Commands.UpdateDepartment;

public record UpdateDepartmentCommand(Guid DepartmentId, string Name, string Description) : ICommand<Result<DepartmentDto>, AuthTransactionOwner>;

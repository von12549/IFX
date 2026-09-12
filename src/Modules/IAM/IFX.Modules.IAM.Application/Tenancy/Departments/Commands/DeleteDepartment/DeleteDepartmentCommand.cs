using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Commands.DeleteDepartment;

public record DeleteDepartmentCommand(Guid DepartmentId) : ICommand<Result<bool>, AuthTransactionOwner>;

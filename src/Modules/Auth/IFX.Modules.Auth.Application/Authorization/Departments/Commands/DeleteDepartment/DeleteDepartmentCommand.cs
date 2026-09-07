using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.DeleteDepartment;

public record DeleteDepartmentCommand(Guid DepartmentId) : ICommand<Result<bool>, AuthTransactionOwner>;

using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Commands.CreateDepartment;

public record CreateDepartmentCommand(string Name, string Description, Guid TenantId) : ICommand<Result<DepartmentDto>, IamTransactionOwner>;

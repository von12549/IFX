using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignDepartmentToUser;

public record AssignDepartmentToUserCommand(Guid UserId, Guid DepartmentId) : ICommand<Result<bool>, AuthTransactionOwner>;

using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.SyncUser;

public record SyncUserCommand(string Issuer, string Subject) : ICommand<Result<UserProfileDto>, AuthTransactionOwner>;

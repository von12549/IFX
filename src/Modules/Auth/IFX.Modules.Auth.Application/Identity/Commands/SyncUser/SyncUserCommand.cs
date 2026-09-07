using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.SyncUser;

public record SyncUserCommand(string Issuer, string Subject) : ICommand<Result<UserProfileDto>, AuthTransactionOwner>;

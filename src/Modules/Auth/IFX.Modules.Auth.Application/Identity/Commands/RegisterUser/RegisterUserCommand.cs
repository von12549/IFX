using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.RegisterUser;

public record RegisterUserCommand(
    string Email,
    string Password,
    string Username,
    string FirstName,
    string LastName,
    string BirthDate,
    string PhoneNumber,
    string IpAddress) : IRequest<Result<RegisterUserResponse>>;

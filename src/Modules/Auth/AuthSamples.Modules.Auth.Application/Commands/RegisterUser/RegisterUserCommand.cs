using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.RegisterUser;

public record RegisterUserCommand(
    string Email,
    string Password,
    string Username,
    string FirstName,
    string LastName,
    string BirthDate,
    string PhoneNumber,
    string IpAddress) : IRequest<Result<RegisterUserResponse>>;

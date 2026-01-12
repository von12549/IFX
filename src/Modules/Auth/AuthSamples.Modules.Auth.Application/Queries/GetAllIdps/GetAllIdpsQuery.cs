using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetAllIdps;

public record GetAllIdpsQuery() : IRequest<Result<List<IdpDto>>>;

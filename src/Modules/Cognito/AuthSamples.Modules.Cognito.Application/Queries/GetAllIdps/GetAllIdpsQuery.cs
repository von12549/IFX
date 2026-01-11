using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Queries.GetAllIdps;

public record GetAllIdpsQuery() : IRequest<Result<List<IdpDto>>>;

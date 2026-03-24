using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Queries.GetAvailableTemplates;

public record GetAvailableTemplatesQuery : IRequest<Result<List<TemplateDto>>>;

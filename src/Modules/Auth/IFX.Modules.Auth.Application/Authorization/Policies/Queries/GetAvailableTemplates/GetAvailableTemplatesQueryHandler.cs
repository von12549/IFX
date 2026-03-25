using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Queries.GetAvailableTemplates;

public class GetAvailableTemplatesQueryHandler
    : IRequestHandler<GetAvailableTemplatesQuery, Result<List<TemplateDto>>>
{
    private readonly IAbacTemplateRegistry _templateRegistry;

    // Human-readable descriptions for well-known built-in templates.
    // Modules may register additional templates; those without a description get a fallback.
    private static readonly Dictionary<string, string> Descriptions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["SameTenant"]     = "Subject and resource must belong to the same tenant.",
        ["CreatedByMe"]    = "Subject must be the owner of the resource.",
        ["SameDepartment"] = "Subject and resource must share at least one department."
    };

    public GetAvailableTemplatesQueryHandler(IAbacTemplateRegistry templateRegistry)
    {
        _templateRegistry = templateRegistry;
    }

    public Task<Result<List<TemplateDto>>> Handle(
        GetAvailableTemplatesQuery request, CancellationToken cancellationToken)
    {
        var templates = _templateRegistry.GetAll()
            .OrderBy(t => t.Name)
            .Select(t => new TemplateDto(
                t.Name,
                Descriptions.TryGetValue(t.Name, out var desc) ? desc : t.Name))
            .ToList();

        return Task.FromResult(Result<List<TemplateDto>>.Success(templates));
    }
}

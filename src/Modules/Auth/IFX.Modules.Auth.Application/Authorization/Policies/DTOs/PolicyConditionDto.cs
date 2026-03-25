namespace IFX.Modules.Auth.Application.Authorization.Policies.DTOs;

public record PolicyConditionDto(
    string TemplateName,
    Dictionary<string, object>? Parameters);

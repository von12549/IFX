namespace IFX.Modules.IAM.Application.Access.Policies.DTOs;

public record PolicyConditionDto(
    string TemplateName,
    Dictionary<string, object>? Parameters);

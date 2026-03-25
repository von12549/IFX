namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public record PolicyConditionRequest(
    string TemplateName,
    Dictionary<string, object>? Parameters);

public record CreatePolicyRequest(
    string Name,
    string? Description,
    string ResourceType,
    string Action,
    List<PolicyConditionRequest> Conditions);

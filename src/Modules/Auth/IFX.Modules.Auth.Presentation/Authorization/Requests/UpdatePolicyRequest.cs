namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public record UpdatePolicyRequest(
    string Name,
    string? Description,
    List<PolicyConditionRequest> Conditions);

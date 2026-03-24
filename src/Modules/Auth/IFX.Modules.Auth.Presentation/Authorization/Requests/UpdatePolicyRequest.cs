namespace IFX.Modules.Auth.Presentation.Authorization.Requests;

public record UpdatePolicyRequest(
    string Name,
    List<PolicyConditionRequest> Conditions);

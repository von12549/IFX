namespace IFX.Modules.IAM.Presentation.Access.Requests;

public record UpdatePolicyRequest(
    string Name,
    string? Description,
    List<PolicyConditionRequest> Conditions);

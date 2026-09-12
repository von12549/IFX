namespace IFX.Platform.Authorization.Contracts.V1;

public interface IAuthorizationEvaluationContract
{
    Task<EvaluationResponse> EvaluateAsync(EvaluationRequest request, CancellationToken ct = default);
}

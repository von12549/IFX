using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.CRM.Contracts.V1;

public interface IAccountComplianceContract
{
    Task<AccountComplianceResponse> CheckAsync(
        AccountComplianceRequest request,
        ContractRequestContext context,
        CancellationToken cancellationToken = default);
}

public sealed record AccountComplianceRequest(Guid InvestmentAccountId, Guid TenantId);

public sealed record AccountComplianceResponse(bool IsApproved);

public sealed class AccountComplianceContractException : Exception
{
    public AccountComplianceContractException(string code)
        : base(code)
    {
        Code = code;
    }

    public string Code { get; }
}

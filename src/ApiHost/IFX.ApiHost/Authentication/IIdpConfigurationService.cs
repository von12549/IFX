namespace IFX.ApiHost.Authentication;

public interface IIdpConfigurationService
{
    Task<IdpConfigurationEntry?> GetByIssuerAsync(string issuer, CancellationToken ct = default);
    Task<IReadOnlyList<IdpConfigurationEntry>> GetAllEnabledAsync(CancellationToken ct = default);
}

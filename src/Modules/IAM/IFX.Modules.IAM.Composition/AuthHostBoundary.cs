using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Queries.GetOrProvisionUser;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using MediatR;

namespace IFX.Modules.IAM.Composition;

public sealed record AuthIdpConfiguration(
    Guid IdpId,
    string Issuer,
    string Authority,
    string IdpType,
    bool AutoProvisionEnabled,
    string ExpectedAudiences,
    string AllowedAlgorithms,
    int ClockSkewSeconds,
    string ClaimMapping);

public interface IAuthIdpConfigurationReader
{
    Task<IReadOnlyList<AuthIdpConfiguration>> ReadEnabledAsync(
        CancellationToken cancellationToken = default);
}

internal sealed class AuthIdpConfigurationReader(IUnitOfWork unitOfWork)
    : IAuthIdpConfigurationReader
{
    public async Task<IReadOnlyList<AuthIdpConfiguration>> ReadEnabledAsync(
        CancellationToken cancellationToken = default)
    {
        var idps = await unitOfWork.Idps.GetEnabledAsync(cancellationToken);
        return idps.Select(idp => new AuthIdpConfiguration(
            idp.Id,
            idp.Issuer,
            idp.Authority,
            idp.IdpType.ToString(),
            idp.AutoProvisionEnabled,
            idp.ExpectedAudiences,
            idp.AllowedAlgs,
            idp.ClockSkewSeconds,
            idp.ClaimMapping)).ToList();
    }
}

public sealed record AuthUserProvisioningRequest(
    string Issuer,
    string Subject,
    string AccessToken,
    bool AutoProvisionEnabled,
    Guid? IdpId,
    string? IdpType,
    string? IpAddress);

public sealed record AuthUserProvisioningResult(
    bool IsSuccess,
    string? Error,
    Guid UserId,
    Guid? PrimaryTenantId,
    IReadOnlyList<Guid> TenantIds,
    IReadOnlyList<string> PermissionNames,
    IReadOnlyList<string> RoleNames,
    IReadOnlyList<string> DepartmentNames);

public interface IAuthUserProvisioningFacade
{
    Task<AuthUserProvisioningResult> GetOrProvisionAsync(
        AuthUserProvisioningRequest request,
        CancellationToken cancellationToken = default);
}

internal sealed class AuthUserProvisioningFacade(ISender sender) : IAuthUserProvisioningFacade
{
    public async Task<AuthUserProvisioningResult> GetOrProvisionAsync(
        AuthUserProvisioningRequest request,
        CancellationToken cancellationToken = default)
    {
        IdpType? idpType = null;
        if (!string.IsNullOrWhiteSpace(request.IdpType)
            && Enum.TryParse<IdpType>(request.IdpType, ignoreCase: true, out var parsed))
        {
            idpType = parsed;
        }

        var result = await sender.Send(new GetOrProvisionUserQuery(
            request.Issuer,
            request.Subject,
            request.AccessToken,
            request.AutoProvisionEnabled,
            request.IdpId,
            idpType,
            request.IpAddress), cancellationToken);

        if (!result.IsSuccess || result.Value is null)
        {
            return new AuthUserProvisioningResult(
                false,
                result.Error,
                Guid.Empty,
                null,
                [],
                [],
                [],
                []);
        }

        var value = result.Value;
        return new AuthUserProvisioningResult(
            true,
            null,
            value.UserId,
            value.PrimaryTenantId,
            value.TenantIds,
            value.PermissionNames,
            value.RoleNames,
            value.DepartmentNames);
    }
}

public interface IAuthIdpCacheVersion
{
    long Version { get; }
}

internal sealed class AuthIdpCacheSignal : IIdpCacheInvalidator, IAuthIdpCacheVersion
{
    private long _version;

    public long Version => Interlocked.Read(ref _version);

    public void InvalidateCache() => Interlocked.Increment(ref _version);
}

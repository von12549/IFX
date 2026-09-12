using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Queries.GetOrProvisionUser;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using MediatR;
using Microsoft.Extensions.Configuration;

namespace IFX.Modules.IAM.Composition;

public sealed record IdentityProviderConfiguration(
    Guid IdpId,
    string Issuer,
    string Authority,
    string IdpType,
    bool AutoProvisionEnabled,
    string ExpectedAudiences,
    string AllowedAlgorithms,
    int ClockSkewSeconds,
    string ClaimMapping,
    string AudienceClaim = "aud",
    string? RequiredTokenUse = null);

public interface IIdentityProviderConfigurationReader
{
    Task<IReadOnlyList<IdentityProviderConfiguration>> ReadEnabledAsync(
        CancellationToken cancellationToken = default);
}

internal sealed class IdentityProviderConfigurationReader(IUnitOfWork unitOfWork, IConfiguration configuration)
    : IIdentityProviderConfigurationReader
{
    public async Task<IReadOnlyList<IdentityProviderConfiguration>> ReadEnabledAsync(
        CancellationToken cancellationToken = default)
    {
        var idps = await unitOfWork.Idps.GetEnabledAsync(cancellationToken);
        var configuredIssuer = configuration["CognitoSettings:Authority"];
        if (string.IsNullOrWhiteSpace(configuredIssuer))
            configuredIssuer = $"https://cognito-idp.{configuration["CognitoSettings:Region"] ?? "us-east-1"}.amazonaws.com/{configuration["CognitoSettings:UserPoolId"]}";
        var configuredClients = new[] { configuration["CognitoSettings:ClientId"], configuration["CognitoOidcSettings:ClientId"] }
            .Where(value => !string.IsNullOrWhiteSpace(value)).Distinct().ToArray();
        return idps.Select(idp =>
        {
            var primaryCognito = (configuration["Authentication:Provider"] ?? "Cognito").Equals("Cognito", StringComparison.OrdinalIgnoreCase) && idp.Issuer == configuredIssuer;
            var audiences = idp.ExpectedAudiences;
            var algorithms = idp.AllowedAlgs;
            if (primaryCognito && audiences.Trim() == "[]") audiences = System.Text.Json.JsonSerializer.Serialize(configuredClients);
            if (primaryCognito && algorithms.Trim() == "[]") algorithms = "[\"RS256\"]";
            var mapping = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(idp.ClaimMapping) ?? [];
            var audienceClaim = mapping.GetValueOrDefault("audienceClaim") ?? (primaryCognito ? "client_id" : "aud");
            return new IdentityProviderConfiguration(
            idp.Id,
            idp.Issuer,
            idp.Authority,
            idp.IdpType.ToString(),
            idp.AutoProvisionEnabled,
            audiences,
            algorithms,
            idp.ClockSkewSeconds,
            idp.ClaimMapping, audienceClaim, audienceClaim == "client_id" ? "access" : null);
        }).ToList();
    }
}

public sealed record LocalIdentityAdmissionRequest(
    string Issuer,
    string Subject,
    string AccessToken,
    bool AutoProvisionEnabled,
    Guid? IdpId,
    string? IdpType,
    string? IpAddress);

public sealed record LocalIdentityAdmissionResult(
    bool IsSuccess,
    string? Error,
    Guid UserId,
    Guid? PrimaryTenantId,
    IReadOnlyList<Guid> TenantIds,
    IReadOnlyList<string> PermissionNames,
    IReadOnlyList<string> RoleNames,
    IReadOnlyList<string> DepartmentNames);

public interface ILocalIdentityAdmission
{
    Task<LocalIdentityAdmissionResult> GetOrProvisionAsync(
        LocalIdentityAdmissionRequest request,
        CancellationToken cancellationToken = default);
}

internal sealed class LocalIdentityAdmission(ISender sender) : ILocalIdentityAdmission
{
    public async Task<LocalIdentityAdmissionResult> GetOrProvisionAsync(
        LocalIdentityAdmissionRequest request,
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
            return new LocalIdentityAdmissionResult(
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
        return new LocalIdentityAdmissionResult(
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

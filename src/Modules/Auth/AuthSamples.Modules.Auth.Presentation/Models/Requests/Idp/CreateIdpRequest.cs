using System.ComponentModel.DataAnnotations;
using AuthSamples.Modules.Auth.Domain.Enums;

namespace AuthSamples.Modules.Auth.Presentation.Models.Requests.Idp;

public class CreateIdpRequest
{
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    public string Issuer { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    public string Authority { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;

    [MaxLength(500)]
    public string LoginUrl { get; set; } = string.Empty;

    public IdpType IdpType { get; set; } = IdpType.Internal;

    public bool IsPrimary { get; set; } = false;

    public bool Enabled { get; set; } = true;

    public bool AutoProvisionEnabled { get; set; } = true;

    public string ExpectedAudiences { get; set; } = "[]";

    public string AllowedAlgs { get; set; } = "[]";

    public string RequiredScopes { get; set; } = "[]";

    public string ClaimMapping { get; set; } = "{}";

    [Range(0, 3600)]
    public int ClockSkewSeconds { get; set; } = 300;
}

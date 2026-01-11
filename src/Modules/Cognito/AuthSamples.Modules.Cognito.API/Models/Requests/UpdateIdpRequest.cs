using System.ComponentModel.DataAnnotations;

namespace AuthSamples.Modules.Cognito.API.Models.Requests;

public class UpdateIdpRequest
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

    public bool Enabled { get; set; }

    public bool AutoProvisionEnabled { get; set; }

    public string ExpectedAudiences { get; set; } = "[]";

    public string AllowedAlgs { get; set; } = "[]";

    public string RequiredScopes { get; set; } = "[]";

    public string ClaimMapping { get; set; } = "{}";

    [Range(0, 3600)]
    public int ClockSkewSeconds { get; set; }
}

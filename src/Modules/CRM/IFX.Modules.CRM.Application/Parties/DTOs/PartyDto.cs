namespace IFX.Modules.CRM.Application.Parties.DTOs;

public class PartyDto
{
    public Guid Id { get; init; }
    public Guid TenantId { get; init; }
    public string PartyCode { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string LegalStructure { get; init; } = string.Empty;
    public List<string> Roles { get; init; } = new();
    public string Status { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}

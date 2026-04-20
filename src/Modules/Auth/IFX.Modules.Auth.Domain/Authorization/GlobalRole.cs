using BaseEntity = IFX.BuildingBlocks.Domain.BaseEntity;
using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Authorization;

public class GlobalRole : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private readonly List<UserGlobalRole> _userGlobalRoles = new();
    public IReadOnlyCollection<UserGlobalRole> UserGlobalRoles => _userGlobalRoles.AsReadOnly();

    private GlobalRole() { } // EF Core

    public static GlobalRole Create(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name must not be empty.", nameof(name));
        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description must not be empty.", nameof(description));

        return new GlobalRole
        {
            Name = name.Trim(),
            Description = description.Trim()
        };
    }
}

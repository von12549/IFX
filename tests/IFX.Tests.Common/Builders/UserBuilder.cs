using IFX.Modules.Auth.Domain.Entities;

namespace IFX.Tests.Common.Builders;

public class UserBuilder
{
    private Guid _userRoleId = Guid.NewGuid();
    private string _displayName = TestConstants.ValidDisplayName;
    private bool _isActive = false;

    public UserBuilder WithRole(Guid roleId)
    {
        _userRoleId = roleId;
        return this;
    }

    public UserBuilder WithDisplayName(string displayName)
    {
        _displayName = displayName;
        return this;
    }

    public UserBuilder Active()
    {
        _isActive = true;
        return this;
    }

    public UserBuilder Inactive()
    {
        _isActive = false;
        return this;
    }

    public User Build() => User.Create(_userRoleId, _displayName, _isActive);
}

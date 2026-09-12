using IFX.Modules.IAM.Domain.Users;

namespace IFX.Tests.Common.Builders;

public class UserBuilder
{
    private string _displayName = TestConstants.ValidDisplayName;
    private bool _isActive = false;

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

    public User Build() => User.Create(_displayName, _isActive);
}

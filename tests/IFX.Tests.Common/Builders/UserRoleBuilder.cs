using IFX.Modules.Auth.Domain.Entities;

namespace IFX.Tests.Common.Builders;

public class UserRoleBuilder
{
    private string _roleName = TestConstants.Roles.User;
    private string _description = "Default user role";

    public UserRoleBuilder WithRoleName(string roleName)
    {
        _roleName = roleName;
        return this;
    }

    public UserRoleBuilder WithDescription(string description)
    {
        _description = description;
        return this;
    }

    public UserRoleBuilder AsAdmin()
    {
        _roleName = TestConstants.Roles.Admin;
        _description = "Administrator with full access";
        return this;
    }

    public UserRoleBuilder AsUser()
    {
        _roleName = TestConstants.Roles.User;
        _description = "Standard user role";
        return this;
    }

    public UserRoleBuilder AsSsoUser()
    {
        _roleName = TestConstants.Roles.SsoUser;
        _description = "SSO authenticated user";
        return this;
    }

    public UserRole Build() => UserRole.Create(_roleName, _description);
}

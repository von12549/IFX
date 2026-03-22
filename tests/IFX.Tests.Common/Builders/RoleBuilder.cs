using IFX.Modules.Auth.Domain.Authorization;

namespace IFX.Tests.Common.Builders;

public class RoleBuilder
{
    private string _name = TestConstants.Roles.User;
    private string _description = "Default user role";

    public RoleBuilder WithName(string name)
    {
        _name = name;
        return this;
    }

    public RoleBuilder WithDescription(string description)
    {
        _description = description;
        return this;
    }

    public RoleBuilder AsAdmin()
    {
        _name = TestConstants.Roles.Admin;
        _description = "Administrator with full access";
        return this;
    }

    public RoleBuilder AsUser()
    {
        _name = TestConstants.Roles.User;
        _description = "Standard user role";
        return this;
    }

    public RoleBuilder AsSsoUser()
    {
        _name = TestConstants.Roles.SsoUser;
        _description = "SSO authenticated user";
        return this;
    }

    public Role Build() => Role.Create(_name, _description, Guid.NewGuid());
}

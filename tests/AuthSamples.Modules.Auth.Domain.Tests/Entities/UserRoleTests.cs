using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Tests.Common;
using AuthSamples.Tests.Common.Builders;

namespace AuthSamples.Modules.Auth.Domain.Tests.Entities;

public class UserRoleTests
{
    [Fact]
    public void Create_WithValidParameters_ReturnsUserRole()
    {
        // Arrange
        var roleName = "Admin";
        var description = "Administrator role with full access";

        // Act
        var role = UserRole.Create(roleName, description);

        // Assert
        role.Should().NotBeNull();
        role.Id.Should().NotBeEmpty();
        role.RoleName.Should().Be(roleName);
        role.Description.Should().Be(description);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Create_WithEmptyRoleName_ThrowsArgumentException(string? roleName)
    {
        // Act
        var act = () => UserRole.Create(roleName!, "Description");

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Role name cannot be empty*");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Create_WithEmptyDescription_ThrowsArgumentException(string? description)
    {
        // Act
        var act = () => UserRole.Create("RoleName", description!);

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Description cannot be empty*");
    }

    [Fact]
    public void Create_TrimsRoleNameAndDescription()
    {
        // Arrange
        var roleName = "  Admin  ";
        var description = "  Administrator role  ";

        // Act
        var role = UserRole.Create(roleName, description);

        // Assert
        role.RoleName.Should().Be("Admin");
        role.Description.Should().Be("Administrator role");
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesRoleNameAndDescription()
    {
        // Arrange
        var role = new UserRoleBuilder().AsUser().Build();
        var newRoleName = "SuperUser";
        var newDescription = "Super user with extended permissions";

        // Act
        role.Update(newRoleName, newDescription);

        // Assert
        role.RoleName.Should().Be(newRoleName);
        role.Description.Should().Be(newDescription);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Update_WithEmptyRoleName_ThrowsArgumentException(string? roleName)
    {
        // Arrange
        var role = new UserRoleBuilder().Build();

        // Act
        var act = () => role.Update(roleName!, "Description");

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Role name cannot be empty*");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Update_WithEmptyDescription_ThrowsArgumentException(string? description)
    {
        // Arrange
        var role = new UserRoleBuilder().Build();

        // Act
        var act = () => role.Update("RoleName", description!);

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Description cannot be empty*");
    }

    [Fact]
    public void Update_TrimsValues()
    {
        // Arrange
        var role = new UserRoleBuilder().Build();

        // Act
        role.Update("  NewRole  ", "  New Description  ");

        // Assert
        role.RoleName.Should().Be("NewRole");
        role.Description.Should().Be("New Description");
    }

    [Fact]
    public void Builder_AsAdmin_CreatesAdminRole()
    {
        // Act
        var role = new UserRoleBuilder().AsAdmin().Build();

        // Assert
        role.RoleName.Should().Be(TestConstants.Roles.Admin);
    }

    [Fact]
    public void Builder_AsUser_CreatesUserRole()
    {
        // Act
        var role = new UserRoleBuilder().AsUser().Build();

        // Assert
        role.RoleName.Should().Be(TestConstants.Roles.User);
    }

    [Fact]
    public void Builder_AsSsoUser_CreatesSsoUserRole()
    {
        // Act
        var role = new UserRoleBuilder().AsSsoUser().Build();

        // Assert
        role.RoleName.Should().Be(TestConstants.Roles.SsoUser);
    }
}

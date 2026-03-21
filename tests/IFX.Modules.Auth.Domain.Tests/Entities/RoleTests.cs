using IFX.Modules.Auth.Domain.Authorization;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;

namespace IFX.Modules.Auth.Domain.Tests.Entities;

public class RoleTests
{
    [Fact]
    public void Create_WithValidParameters_ReturnsRole()
    {
        // Arrange
        var name = "Admin";
        var description = "Administrator role with full access";

        // Act
        var role = Role.Create(name, description);

        // Assert
        role.Should().NotBeNull();
        role.Id.Should().NotBeEmpty();
        role.Name.Should().Be(name);
        role.Description.Should().Be(description);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Create_WithEmptyName_ThrowsArgumentException(string? name)
    {
        // Act
        var act = () => Role.Create(name!, "Description");

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
        var act = () => Role.Create("RoleName", description!);

        // Assert
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Description cannot be empty*");
    }

    [Fact]
    public void Create_TrimsNameAndDescription()
    {
        // Arrange
        var name = "  Admin  ";
        var description = "  Administrator role  ";

        // Act
        var role = Role.Create(name, description);

        // Assert
        role.Name.Should().Be("Admin");
        role.Description.Should().Be("Administrator role");
    }

    [Fact]
    public void Update_WithValidParameters_UpdatesNameAndDescription()
    {
        // Arrange
        var role = new RoleBuilder().AsUser().Build();
        var newName = "SuperUser";
        var newDescription = "Super user with extended permissions";

        // Act
        role.Update(newName, newDescription);

        // Assert
        role.Name.Should().Be(newName);
        role.Description.Should().Be(newDescription);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Update_WithEmptyName_ThrowsArgumentException(string? name)
    {
        // Arrange
        var role = new RoleBuilder().Build();

        // Act
        var act = () => role.Update(name!, "Description");

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
        var role = new RoleBuilder().Build();

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
        var role = new RoleBuilder().Build();

        // Act
        role.Update("  NewRole  ", "  New Description  ");

        // Assert
        role.Name.Should().Be("NewRole");
        role.Description.Should().Be("New Description");
    }

    [Fact]
    public void Builder_AsAdmin_CreatesAdminRole()
    {
        // Act
        var role = new RoleBuilder().AsAdmin().Build();

        // Assert
        role.Name.Should().Be(TestConstants.Roles.Admin);
    }

    [Fact]
    public void Builder_AsUser_CreatesUserRole()
    {
        // Act
        var role = new RoleBuilder().AsUser().Build();

        // Assert
        role.Name.Should().Be(TestConstants.Roles.User);
    }

    [Fact]
    public void Builder_AsSsoUser_CreatesSsoUserRole()
    {
        // Act
        var role = new RoleBuilder().AsSsoUser().Build();

        // Assert
        role.Name.Should().Be(TestConstants.Roles.SsoUser);
    }
}

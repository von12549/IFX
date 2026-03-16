using IFX.Modules.Auth.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;

namespace IFX.Modules.Auth.Domain.Tests.Entities;

public class UserTests
{
    [Fact]
    public void Create_WithValidParameters_ReturnsUser()
    {
        // Arrange
        var roleId = Guid.NewGuid();
        var displayName = "John Doe";

        // Act
        var user = User.Create(roleId, displayName);

        // Assert
        user.Should().NotBeNull();
        user.Id.Should().NotBeEmpty();
        user.UserRoleId.Should().Be(roleId);
        user.DisplayName.Should().Be(displayName);
        user.IsActive.Should().BeFalse();
    }

    [Fact]
    public void Create_WithIsActiveTrue_SetsIsActive()
    {
        // Arrange
        var roleId = Guid.NewGuid();

        // Act
        var user = User.Create(roleId, "Test User", isActive: true);

        // Assert
        user.IsActive.Should().BeTrue();
    }

    [Fact]
    public void Activate_SetsIsActiveTrue()
    {
        // Arrange
        var user = new UserBuilder().Inactive().Build();
        user.IsActive.Should().BeFalse();

        // Act
        user.Activate();

        // Assert
        user.IsActive.Should().BeTrue();
    }

    [Fact]
    public void Deactivate_SetsIsActiveFalse()
    {
        // Arrange
        var user = new UserBuilder().Active().Build();
        user.IsActive.Should().BeTrue();

        // Act
        user.Deactivate();

        // Assert
        user.IsActive.Should().BeFalse();
    }

    [Fact]
    public void UpdateDisplayName_UpdatesDisplayName()
    {
        // Arrange
        var user = new UserBuilder().WithDisplayName("Old Name").Build();
        var newDisplayName = "New Name";

        // Act
        user.UpdateDisplayName(newDisplayName);

        // Assert
        user.DisplayName.Should().Be(newDisplayName);
    }

    [Fact]
    public void AssignRole_UpdatesUserRoleId()
    {
        // Arrange
        var user = new UserBuilder().Build();
        var newRoleId = Guid.NewGuid();

        // Act
        user.AssignRole(newRoleId);

        // Assert
        user.UserRoleId.Should().Be(newRoleId);
    }

    [Fact]
    public void Builder_CreatesUserWithCorrectDefaults()
    {
        // Act
        var user = new UserBuilder().Build();

        // Assert
        user.Should().NotBeNull();
        user.DisplayName.Should().Be(TestConstants.ValidDisplayName);
        user.IsActive.Should().BeFalse();
    }

    [Fact]
    public void Builder_Active_CreatesActiveUser()
    {
        // Act
        var user = new UserBuilder().Active().Build();

        // Assert
        user.IsActive.Should().BeTrue();
    }
}

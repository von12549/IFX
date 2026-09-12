using IFX.Modules.IAM.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;

namespace IFX.Modules.IAM.Domain.Tests.Entities;

public class UserTests
{
    [Fact]
    public void Create_WithValidParameters_ReturnsUser()
    {
        // Arrange
        var displayName = "John Doe";

        // Act
        var user = User.Create(displayName);

        // Assert
        user.Should().NotBeNull();
        user.Id.Should().NotBeEmpty();
        user.DisplayName.Should().Be(displayName);
        user.IsActive.Should().BeFalse();
    }

    [Fact]
    public void Create_WithIsActiveTrue_SetsIsActive()
    {
        // Act
        var user = User.Create("Test User", isActive: true);

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

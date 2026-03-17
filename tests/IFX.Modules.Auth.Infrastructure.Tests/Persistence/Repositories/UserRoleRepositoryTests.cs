using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Authorization.Repositories;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Tests.Persistence.Repositories;

public class UserRoleRepositoryTests : IDisposable
{
    private readonly IfxDbContext _context;
    private readonly UserRoleRepository _repository;

    public UserRoleRepositoryTests()
    {
        var options = new DbContextOptionsBuilder<IfxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new IfxDbContext(options);
        _repository = new UserRoleRepository(_context);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Fact]
    public async Task GetByIdAsync_WithExistingRole_ReturnsRole()
    {
        // Arrange
        var role = new UserRoleBuilder().AsAdmin().Build();
        await _context.UserRoles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetByIdAsync(role.Id);

        // Assert
        result.Should().NotBeNull();
        result!.RoleName.Should().Be(TestConstants.Roles.Admin);
    }

    [Fact]
    public async Task GetByIdAsync_WithNonExistingRole_ReturnsNull()
    {
        // Act
        var result = await _repository.GetByIdAsync(Guid.NewGuid());

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByRoleNameAsync_WithExistingRole_ReturnsRole()
    {
        // Arrange
        var role = new UserRoleBuilder().AsUser().Build();
        await _context.UserRoles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetByRoleNameAsync(TestConstants.Roles.User);

        // Assert
        result.Should().NotBeNull();
        result!.RoleName.Should().Be(TestConstants.Roles.User);
    }

    [Fact]
    public async Task GetByRoleNameAsync_WithNonExistingRole_ReturnsNull()
    {
        // Act
        var result = await _repository.GetByRoleNameAsync("NonExistent");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task RoleNameExistsAsync_WithExistingRole_ReturnsTrue()
    {
        // Arrange
        var role = new UserRoleBuilder().AsAdmin().Build();
        await _context.UserRoles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.RoleNameExistsAsync(TestConstants.Roles.Admin);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task RoleNameExistsAsync_WithNonExistingRole_ReturnsFalse()
    {
        // Act
        var result = await _repository.RoleNameExistsAsync("NonExistent");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task RoleNameExistsAsync_WithExcludeId_ExcludesSpecifiedRole()
    {
        // Arrange
        var role = new UserRoleBuilder().AsAdmin().Build();
        await _context.UserRoles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.RoleNameExistsAsync(TestConstants.Roles.Admin, role.Id);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllRoles()
    {
        // Arrange
        var adminRole = new UserRoleBuilder().AsAdmin().Build();
        var userRole = new UserRoleBuilder().AsUser().Build();
        await _context.UserRoles.AddRangeAsync(adminRole, userRole);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetAllAsync();

        // Assert
        result.Should().HaveCount(2);
        result.Select(r => r.RoleName).Should().Contain(TestConstants.Roles.Admin);
        result.Select(r => r.RoleName).Should().Contain(TestConstants.Roles.User);
    }

    [Fact]
    public async Task AddAsync_AddsRoleToContext()
    {
        // Arrange
        var role = new UserRoleBuilder()
            .WithRoleName("NewRole")
            .WithDescription("New role description")
            .Build();

        // Act
        await _repository.AddAsync(role);
        await _context.SaveChangesAsync();

        // Assert
        var savedRole = await _context.UserRoles.FirstOrDefaultAsync(r => r.RoleName == "NewRole");
        savedRole.Should().NotBeNull();
        savedRole!.Description.Should().Be("New role description");
    }

}

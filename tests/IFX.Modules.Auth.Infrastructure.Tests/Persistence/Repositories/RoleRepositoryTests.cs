using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Authorization.Repositories;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Tests.Persistence.Repositories;

public class RoleRepositoryTests : IDisposable
{
    private readonly IfxDbContext _context;
    private readonly RoleRepository _repository;

    public RoleRepositoryTests()
    {
        var options = new DbContextOptionsBuilder<IfxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new IfxDbContext(options);
        _repository = new RoleRepository(_context);
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
        var role = new RoleBuilder().AsAdmin().Build();
        await _context.Roles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetByIdAsync(role.Id);

        // Assert
        result.Should().NotBeNull();
        result!.Name.Should().Be(TestConstants.Roles.Admin);
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
    public async Task GetByNameAsync_WithExistingRole_ReturnsRole()
    {
        // Arrange
        var role = new RoleBuilder().AsUser().Build();
        await _context.Roles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetByNameAsync(TestConstants.Roles.User);

        // Assert
        result.Should().NotBeNull();
        result!.Name.Should().Be(TestConstants.Roles.User);
    }

    [Fact]
    public async Task GetByNameAsync_WithNonExistingRole_ReturnsNull()
    {
        // Act
        var result = await _repository.GetByNameAsync("NonExistent");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task NameExistsAsync_WithExistingRole_ReturnsTrue()
    {
        // Arrange
        var role = new RoleBuilder().AsAdmin().Build();
        await _context.Roles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.NameExistsAsync(TestConstants.Roles.Admin, role.TenantId);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task NameExistsAsync_WithNonExistingRole_ReturnsFalse()
    {
        // Act
        var result = await _repository.NameExistsAsync("NonExistent", Guid.NewGuid());

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task NameExistsAsync_WithExcludeId_ExcludesSpecifiedRole()
    {
        // Arrange
        var role = new RoleBuilder().AsAdmin().Build();
        await _context.Roles.AddAsync(role);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.NameExistsAsync(TestConstants.Roles.Admin, role.TenantId, role.Id);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllRoles()
    {
        // Arrange
        var adminRole = new RoleBuilder().AsAdmin().Build();
        var userRole = new RoleBuilder().AsUser().Build();
        await _context.Roles.AddRangeAsync(adminRole, userRole);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetAllAsync();

        // Assert
        result.Should().HaveCount(2);
        result.Select(r => r.Name).Should().Contain(TestConstants.Roles.Admin);
        result.Select(r => r.Name).Should().Contain(TestConstants.Roles.User);
    }

    [Fact]
    public async Task AddAsync_AddsRoleToContext()
    {
        // Arrange
        var role = new RoleBuilder()
            .WithName("NewRole")
            .WithDescription("New role description")
            .Build();

        // Act
        await _repository.AddAsync(role);
        await _context.SaveChangesAsync();

        // Assert
        var savedRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "NewRole");
        savedRole.Should().NotBeNull();
        savedRole!.Description.Should().Be("New role description");
    }
}

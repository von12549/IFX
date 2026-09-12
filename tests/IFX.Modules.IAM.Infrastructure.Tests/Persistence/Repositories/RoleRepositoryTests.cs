using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Access.Repositories;
using IFX.Modules.IAM.Infrastructure.Tenancy.Repositories;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Tests.Persistence.Repositories;

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
        var result = await _repository.GetByIdAsync(role.Id, role.TenantId);

        // Assert
        result.Should().NotBeNull();
        result!.Name.Should().Be(TestConstants.Roles.Admin);
    }

    [Fact]
    public async Task GetByIdAsync_WithNonExistingRole_ReturnsNull()
    {
        // Act
        var result = await _repository.GetByIdAsync(Guid.NewGuid(), Guid.NewGuid());

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByIdAsync_WithDifferentTenant_ReturnsNull()
    {
        var role = new RoleBuilder().AsAdmin().Build();
        await _context.Roles.AddAsync(role);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByIdAsync(role.Id, Guid.NewGuid());

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
        var result = await _repository.GetByNameAsync(TestConstants.Roles.User, role.TenantId);

        // Assert
        result.Should().NotBeNull();
        result!.Name.Should().Be(TestConstants.Roles.User);
    }

    [Fact]
    public async Task GetByNameAsync_WithNonExistingRole_ReturnsNull()
    {
        // Act
        var result = await _repository.GetByNameAsync("NonExistent", Guid.NewGuid());

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
        var tenant = Tenant.Create("Test Tenant", "For tests");
        await _context.Tenants.AddAsync(tenant);
        await _context.SaveChangesAsync();

        var adminRole = Role.Create(TestConstants.Roles.Admin, "Admin role", tenant.Id);
        var userRole = Role.Create(TestConstants.Roles.User, "User role", tenant.Id);
        await _context.Roles.AddRangeAsync(adminRole, userRole);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetAcrossTenantsAsync(500);

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

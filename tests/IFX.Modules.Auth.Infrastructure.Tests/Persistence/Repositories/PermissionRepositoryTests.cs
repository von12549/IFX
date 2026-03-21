using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Authorization.Repositories;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Tests.Persistence.Repositories;

public class PermissionRepositoryTests : IDisposable
{
    private readonly IfxDbContext _context;
    private readonly PermissionRepository _repository;

    public PermissionRepositoryTests()
    {
        var options = new DbContextOptionsBuilder<IfxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new IfxDbContext(options);
        _repository = new PermissionRepository(_context);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Fact]
    public async Task GetByIdAsync_WithExistingPermission_ReturnsPermission()
    {
        var perm = Permission.Create("Role.Read", "Read roles");
        await _context.Permissions.AddAsync(perm);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByIdAsync(perm.Id);

        result.Should().NotBeNull();
        result!.Name.Should().Be("Role.Read");
    }

    [Fact]
    public async Task GetByIdAsync_WithNonExistingPermission_ReturnsNull()
    {
        var result = await _repository.GetByIdAsync(Guid.NewGuid());
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByNameAsync_WithExistingPermission_ReturnsPermission()
    {
        var perm = Permission.Create("User.Write", "Write users");
        await _context.Permissions.AddAsync(perm);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByNameAsync("User.Write");

        result.Should().NotBeNull();
        result!.Name.Should().Be("User.Write");
    }

    [Fact]
    public async Task GetByNameAsync_WithNonExistingPermission_ReturnsNull()
    {
        var result = await _repository.GetByNameAsync("NonExistent");
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllPermissions()
    {
        await _context.Permissions.AddRangeAsync(
            Permission.Create("Role.Read", "Read roles"),
            Permission.Create("User.Read", "Read users"));
        await _context.SaveChangesAsync();

        var result = await _repository.GetAllAsync();

        result.Should().HaveCount(2);
        result.Select(p => p.Name).Should().Contain("Role.Read").And.Contain("User.Read");
    }

    [Fact]
    public async Task AddAsync_AddsPermissionToContext()
    {
        var perm = Permission.Create("Idp.Read", "Read idps");

        await _repository.AddAsync(perm);
        await _context.SaveChangesAsync();

        var saved = await _context.Permissions.FirstOrDefaultAsync(p => p.Name == "Idp.Read");
        saved.Should().NotBeNull();
    }

    [Fact]
    public async Task NameExistsAsync_WithExistingPermission_ReturnsTrue()
    {
        await _context.Permissions.AddAsync(Permission.Create("Role.Read", "Read roles"));
        await _context.SaveChangesAsync();

        var result = await _repository.NameExistsAsync("Role.Read");

        result.Should().BeTrue();
    }

    [Fact]
    public async Task NameExistsAsync_WithNonExistingPermission_ReturnsFalse()
    {
        var result = await _repository.NameExistsAsync("NonExistent");
        result.Should().BeFalse();
    }

    [Fact]
    public async Task NameExistsAsync_WithExcludeId_ExcludesSpecifiedPermission()
    {
        var perm = Permission.Create("Role.Read", "Read roles");
        await _context.Permissions.AddAsync(perm);
        await _context.SaveChangesAsync();

        var result = await _repository.NameExistsAsync("Role.Read", perm.Id);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task Remove_RemovesPermissionFromContext()
    {
        var perm = Permission.Create("Temp.Read", "Temp");
        await _context.Permissions.AddAsync(perm);
        await _context.SaveChangesAsync();

        _repository.Remove(perm);
        await _context.SaveChangesAsync();

        var remaining = await _context.Permissions.ToListAsync();
        remaining.Should().NotContain(p => p.Name == "Temp.Read");
    }
}

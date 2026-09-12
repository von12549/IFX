using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Access.Repositories;
using IFX.Modules.IAM.Infrastructure.Tenancy.Repositories;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Tests.Common.Builders;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Tests.Persistence.Repositories;

public class RoleGroupRepositoryTests : IDisposable
{
    private readonly IfxDbContext _context;
    private readonly RoleGroupRepository _repository;

    public RoleGroupRepositoryTests()
    {
        var options = new DbContextOptionsBuilder<IfxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new IfxDbContext(options);
        _repository = new RoleGroupRepository(_context);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Fact]
    public async Task GetByIdAsync_WithExistingGroup_ReturnsGroup()
    {
        var group = RoleGroup.Create("Managers", "Manager group", Guid.NewGuid());
        await _context.RoleGroups.AddAsync(group);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByIdAsync(group.Id, group.TenantId);

        result.Should().NotBeNull();
        result!.Name.Should().Be("Managers");
    }

    [Fact]
    public async Task GetByIdAsync_WithNonExistingGroup_ReturnsNull()
    {
        var result = await _repository.GetByIdAsync(Guid.NewGuid(), Guid.NewGuid());
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByIdAsync_WithDifferentTenant_ReturnsNull()
    {
        var group = RoleGroup.Create("Managers", "Manager group", Guid.NewGuid());
        await _context.RoleGroups.AddAsync(group);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByIdAsync(group.Id, Guid.NewGuid());

        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByNameAsync_WithExistingGroup_ReturnsGroup()
    {
        var group = RoleGroup.Create("Admins", "Admin group", Guid.NewGuid());
        await _context.RoleGroups.AddAsync(group);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByNameAsync("Admins", group.TenantId);

        result.Should().NotBeNull();
        result!.Name.Should().Be("Admins");
    }

    [Fact]
    public async Task GetByNameAsync_WithNonExistingGroup_ReturnsNull()
    {
        var result = await _repository.GetByNameAsync("NonExistent", Guid.NewGuid());
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByIdWithRolesAsync_ReturnsGroupWithRoles()
    {
        var role = new RoleBuilder().AsUser().Build();
        var group = RoleGroup.Create("Staff", "Staff group", role.TenantId);
        await _context.Roles.AddAsync(role);
        await _context.RoleGroups.AddAsync(group);
        await _context.SaveChangesAsync();

        // Add role to group via EF navigation (requires reload)
        var savedGroup = await _context.RoleGroups
            .Include(g => g.Roles)
            .FirstAsync(g => g.Id == group.Id);
        savedGroup.AddRole(role);
        await _context.SaveChangesAsync();

        var result = await _repository.GetByIdWithRolesAsync(group.Id, group.TenantId);

        result.Should().NotBeNull();
        result!.Roles.Should().HaveCount(1);
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllGroups()
    {
        var tenant = Tenant.Create("Test Tenant", "For tests");
        await _context.Tenants.AddAsync(tenant);
        await _context.SaveChangesAsync();

        await _context.RoleGroups.AddRangeAsync(
            RoleGroup.Create("Managers", "Manager group", tenant.Id),
            RoleGroup.Create("Developers", "Dev group", tenant.Id));
        await _context.SaveChangesAsync();

        var result = await _repository.GetAcrossTenantsAsync(500);

        result.Should().HaveCount(2);
        result.Select(g => g.Name).Should().Contain("Managers").And.Contain("Developers");
    }

    [Fact]
    public async Task AddAsync_AddsGroupToContext()
    {
        var group = RoleGroup.Create("NewGroup", "A new group", Guid.NewGuid());

        await _repository.AddAsync(group);
        await _context.SaveChangesAsync();

        var saved = await _context.RoleGroups.FirstOrDefaultAsync(g => g.Name == "NewGroup");
        saved.Should().NotBeNull();
    }

    [Fact]
    public async Task NameExistsAsync_WithExistingGroup_ReturnsTrue()
    {
        var tenantId = Guid.NewGuid();
        await _context.RoleGroups.AddAsync(RoleGroup.Create("Managers", "Manager group", tenantId));
        await _context.SaveChangesAsync();

        var result = await _repository.NameExistsAsync("Managers", tenantId);

        result.Should().BeTrue();
    }

    [Fact]
    public async Task NameExistsAsync_WithNonExistingGroup_ReturnsFalse()
    {
        var result = await _repository.NameExistsAsync("NonExistent", Guid.NewGuid());
        result.Should().BeFalse();
    }

    [Fact]
    public async Task NameExistsAsync_WithExcludeId_ExcludesSpecifiedGroup()
    {
        var group = RoleGroup.Create("Managers", "Manager group", Guid.NewGuid());
        await _context.RoleGroups.AddAsync(group);
        await _context.SaveChangesAsync();

        var result = await _repository.NameExistsAsync("Managers", group.TenantId, group.Id);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task Remove_RemovesGroupFromContext()
    {
        var group = RoleGroup.Create("TempGroup", "Temp", Guid.NewGuid());
        await _context.RoleGroups.AddAsync(group);
        await _context.SaveChangesAsync();

        _repository.Remove(group);
        await _context.SaveChangesAsync();

        var remaining = await _context.RoleGroups.ToListAsync();
        remaining.Should().NotContain(g => g.Name == "TempGroup");
    }
}

using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.Modules.IAM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

[Collection(SqlServerMigrationCollection.Name)]
public sealed class Plan05ReleaseSqlServerTests(SqlServerMigrationFixture fixture)
{
    private const string Previous = "20260908015924_RemoveLoginEventSecrets";
    private const string Expansion = "20260912101127_EnforceActiveTenantMembership";

    [Fact]
    public async Task Release_readiness_requires_expansion_and_explicit_old_consumer_compatibility()
    {
        await using var db = Context(await fixture.CreateDatabaseAsync("p05release"));
        var current = Requirement();
        var old = current with { RequiredMigrationId = Previous, RequiredMigrationIds = current.RequiredMigrationIds.Where(id => id != Expansion).ToArray() };
        await db.GetService<IMigrator>().MigrateAsync(Previous);
        var applied = (await db.Database.GetAppliedMigrationsAsync()).ToArray();
        Assert.True(SchemaCompatibilityPlanner.Evaluate(old, applied).IsCompatible);
        Assert.Equal("required-migration-missing", SchemaCompatibilityPlanner.Evaluate(current, applied).Code);
        await db.Database.MigrateAsync();
        applied = (await db.Database.GetAppliedMigrationsAsync()).ToArray();
        Assert.True(SchemaCompatibilityPlanner.Evaluate(current, applied).IsCompatible);
        Assert.Equal("additional-migration-not-compatible", SchemaCompatibilityPlanner.Evaluate(old, applied).Code);
        Assert.Equal("newer-expand-compatible", SchemaCompatibilityPlanner.Evaluate(old with { CompatibleAdditionalMigrationIds = [Expansion] }, applied).Code);
    }

    [Fact]
    public async Task Isolated_structural_down_and_reapply_preserve_unchanged_membership_rows()
    {
        await using var db = Context(await fixture.CreateDatabaseAsync("p05rollback"));
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync(Previous);
        var tenant = Guid.NewGuid(); var user = Guid.NewGuid();
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.Tenants (Id,Name,Description,CreatedAt,UpdatedAt) VALUES ({tenant},N'rollback',N'test',SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET())");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.Users (Id,DisplayName,IsActive,PrimaryTenantId,CreatedAt,UpdatedAt) VALUES ({user},N'member',1,{tenant},SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET())");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.UserTenants (UserId,TenantsId) VALUES ({user},{tenant})");
        await migrator.MigrateAsync();
        // Down is exercised only in a disposable database with no tenant deactivation or new state.
        await migrator.MigrateAsync(Previous);
        Assert.False(SchemaCompatibilityPlanner.Evaluate(Requirement(), (await db.Database.GetAppliedMigrationsAsync()).ToArray()).IsCompatible);
        Assert.Equal(1, await db.Database.SqlQuery<int>($"SELECT COUNT(*) AS Value FROM auth.UserTenants WHERE UserId={user} AND TenantsId={tenant}").SingleAsync());
        await migrator.MigrateAsync();
        var restored = await db.Users.AsNoTracking().Include(u => u.Tenants).SingleAsync(u => u.Id == user);
        Assert.Equal(tenant, restored.PrimaryTenantId);
        Assert.True(Assert.Single(restored.Tenants).IsActive);
    }

    [Fact]
    public async Task Additive_schema_compatibility_does_not_make_old_tenant_admission_semantically_safe()
    {
        await using var db = Context(await fixture.CreateDatabaseAsync("p05behavior"));
        await db.Database.MigrateAsync();
        var tenant = IFX.Modules.IAM.Domain.Tenancy.Tenant.Create("disabled", "test");
        var user = IFX.Modules.IAM.Domain.Users.User.Create("member", true);
        user.AddTenant(tenant); db.Users.Add(user); await db.SaveChangesAsync();
        tenant.Deactivate(); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        // The old shape still sees membership; therefore a structural allowlist alone cannot authorize rollback.
        Assert.Equal(1, await db.Database.SqlQuery<int>($"SELECT COUNT(*) AS Value FROM auth.UserTenants WHERE UserId={user.Id} AND TenantsId={tenant.Id}").SingleAsync());
        Assert.False(await db.Users.AsNoTracking().Where(u => u.Id == user.Id && u.IsActive).AnyAsync(u => u.Tenants.Any(t => t.Id == tenant.Id && t.IsActive)));
        await db.Database.MigrateAsync(); // Retain the deny state and schema on retry, rather than applying Down.
        Assert.False(await db.Tenants.Where(t => t.Id == tenant.Id).Select(t => t.IsActive).SingleAsync());
    }

    private static ModuleSchemaRequirement Requirement()
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root is not null && !File.Exists(Path.Combine(root.FullName, "IFX.sln"))) root = root.Parent;
        Assert.NotNull(root);
        return ReleaseSchemaManifest.Load(Path.Combine(root.FullName, "deployment/release-manifest.json")).Modules.Single(m => m.ModuleName == "Auth");
    }

    private static IfxDbContext Context(string connection) => new(new DbContextOptionsBuilder<IfxDbContext>().UseSqlServer(connection, sql => sql.MigrationsHistoryTable("__EFMigrationsHistory", "auth")).Options);
}

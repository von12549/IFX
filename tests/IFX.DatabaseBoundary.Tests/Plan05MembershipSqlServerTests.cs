using System.Data;
using System.Security.Claims;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Users;
using IFX.Modules.IAM.Infrastructure.Access;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Modules.IAM.Infrastructure.Users.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

[Collection(SqlServerMigrationCollection.Name)]
public sealed class Plan05MembershipSqlServerTests(SqlServerMigrationFixture fixture)
{
    [Fact]
    public async Task Expansion_preserves_existing_memberships_and_roles_and_is_repeatable()
    {
        var connection = await fixture.CreateDatabaseAsync("p05expand");
        await using var db = Context(connection);
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync("20260908015924_RemoveLoginEventSecrets");
        // The old schema is intentionally accessed via SQL; the new model requires the new column.
        var id = Guid.NewGuid(); var tenant = Guid.NewGuid();
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.Tenants (Id,Name,Description,CreatedAt,UpdatedAt) VALUES ({tenant},N'old tenant',N'test',SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET())");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.Users (Id,DisplayName,IsActive,PrimaryTenantId,CreatedAt,UpdatedAt) VALUES ({id},N'old user',1,{tenant},SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET())");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.UserTenants (UserId,TenantsId) VALUES ({id},{tenant})");
        await migrator.MigrateAsync(); await migrator.MigrateAsync();
        var user = await new UserRepository(db).GetByIdWithTenantsAndDepartmentsAsync(id);
        Assert.Single(user!.Tenants); Assert.True(user.Tenants.Single().IsActive);
        Assert.Equal(tenant, user.PrimaryTenantId); Assert.Empty(user.Roles);
        Assert.Empty(await Audit(db));
    }

    [Fact]
    public async Task Exit_clears_only_the_departing_tenant_assignments_and_primary_preference_atomically()
    {
        var connection = await fixture.CreateDatabaseAsync("p05exit");
        await using var db = Context(connection); await db.Database.MigrateAsync();
        var (user, tenant, role) = Seed(db);
        var other = Tenant.Create("other", "test"); var otherRole = Role.Create("Other", "test", other.Id);
        user.AddTenant(other); user.AddRole(otherRole);
        var group = RoleGroup.Create("Group", "test", tenant.Id); group.AddRole(role); user.AddRoleGroup(group);
        user.AddDepartment(Department.Create("Department", "test", tenant.Id));
        db.Users.Add(user); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        user = (await new UserRepository(db).GetByIdWithTenantsAndDepartmentsAsync(user.Id))!;
        user.RemoveTenant(tenant.Id); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        user = (await new UserRepository(db).GetByIdWithTenantsAndDepartmentsAsync(user.Id))!;
        Assert.Null(user.PrimaryTenantId); Assert.Equal(other.Id, Assert.Single(user.Tenants).Id);
        Assert.Equal(otherRole.Id, Assert.Single(user.Roles).Id); Assert.Empty(user.RoleGroups); Assert.Empty(user.Departments);
        user.SetPrimaryTenant(other.Id); user.AddTenant(other); await db.SaveChangesAsync();
        Assert.Empty(await Audit(db));
    }

    [Theory]
    [InlineData("exit")]
    [InlineData("user-stop")]
    [InlineData("tenant-stop")]
    [InlineData("role-revoke")]
    public async Task Existing_http_and_worker_contexts_reload_revoked_facts_at_the_next_gate(string change)
    {
        var connection = await fixture.CreateDatabaseAsync("p05revoke");
        await using var writer = Context(connection); await writer.Database.MigrateAsync();
        var (user, tenant, role) = Seed(writer); writer.Users.Add(user); await writer.SaveChangesAsync();
        await using var reader = Context(connection);
        var execution = new Scope(user.Id, tenant.Id);
        var http = Facts(reader, execution, user.Id, true); var worker = Facts(reader, execution, user.Id, false);
        Assert.True(await new PermissionChecker(new CurrentUser(http), execution).HasPermissionAsync("User:update"));
        Assert.True(await new PermissionChecker(new CurrentUser(worker), execution).HasPermissionAsync("User:update"));
        switch (change)
        {
            case "exit": user.RemoveTenant(tenant.Id); break;
            case "user-stop": user.Deactivate(); break;
            case "tenant-stop": tenant.Deactivate(); break;
            case "role-revoke": user.RemoveRole(role.Id); break;
        }
        await writer.SaveChangesAsync();
        Assert.False(await new PermissionChecker(new CurrentUser(http), execution).HasPermissionAsync("User:update"));
        Assert.False(await new PermissionChecker(new CurrentUser(worker), execution).HasPermissionAsync("User:update"));
        if (change != "role-revoke") Assert.False(http.IsTenantMember(tenant.Id));
    }

    [Fact]
    public async Task Persistence_rejects_an_orphan_grant_even_when_the_domain_method_is_bypassed()
    {
        var connection = await fixture.CreateDatabaseAsync("p05guard");
        await using var db = Context(connection); await db.Database.MigrateAsync();
        var (user, tenant, role) = Seed(db); db.Users.Add(user); await db.SaveChangesAsync();
        user.RemoveTenant(tenant.Id); await db.SaveChangesAsync();
        var join = db.Model.GetEntityTypes().Single(e => e.GetTableName() == "UserRoles");
        db.Set<Dictionary<string, object>>(join.Name).Add(new() { ["UserId"] = user.Id, ["RolesId"] = role.Id });
        var failure = await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
        Assert.Equal("iam_membership_relation_invalid", failure.Message);
        await using var verify = Context(connection); Assert.Empty(await Audit(verify));
        Assert.False(await verify.Users.Where(u => u.Id == user.Id).AnyAsync(u => u.Roles.Any()));
    }

    [Fact]
    public async Task Concurrent_grant_and_exit_cannot_commit_an_orphan_assignment()
    {
        var connection = await fixture.CreateDatabaseAsync("p05race");
        await using var db = Context(connection); await db.Database.MigrateAsync();
        var (user, tenant, role) = Seed(db); user.RemoveRole(role.Id); db.Users.Add(user); db.Roles.Add(role); await db.SaveChangesAsync();
        await using var grantDb = Context(connection); await using var exitDb = Context(connection);
        var grantUser = (await new UserRepository(grantDb).GetByIdWithRolesAndGroupsAsync(user.Id))!;
        var exitUser = (await new UserRepository(exitDb).GetByIdWithTenantsAndDepartmentsAsync(user.Id))!;
        grantUser.AddRole(await grantDb.Roles.SingleAsync(r => r.Id == role.Id)); exitUser.RemoveTenant(tenant.Id);
        // Both handlers read the old membership, then race their deferred commits.
        var attempts = await Task.WhenAll(Save(grantDb), Save(exitDb));
        Assert.Contains(attempts, succeeded => succeeded);
        await using var verify = Context(connection); Assert.Empty(await Audit(verify));
        if (attempts[1]) Assert.False(await verify.Users.Where(u => u.Id == user.Id).AnyAsync(u => u.Roles.Any()));
    }

    [Fact]
    public async Task Legacy_orphan_grants_are_reported_and_never_create_membership_or_permissions()
    {
        var connection = await fixture.CreateDatabaseAsync("p05legacygrant");
        await using var db = Context(connection); await db.Database.MigrateAsync();
        var (user, tenant, role) = Seed(db); db.Users.Add(user); await db.SaveChangesAsync(); user.RemoveTenant(tenant.Id); await db.SaveChangesAsync();
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT auth.UserRoles (UserId,RolesId) VALUES ({user.Id},{role.Id})");
        Assert.Contains("role_without_membership", await Audit(db));
        var facts = Facts(db, new Scope(user.Id, tenant.Id), user.Id, true);
        Assert.True(facts.IsAuthenticated); Assert.Null(facts.TenantId); Assert.Empty(facts.Permissions); Assert.False(facts.IsTenantMember(tenant.Id));
        Assert.Contains("role_without_membership", await Audit(db));
    }

    private static async Task<bool> Save(IfxDbContext db)
    {
        try { await db.SaveChangesAsync(); return true; }
        catch (InvalidOperationException ex) when (ex.Message == "iam_membership_relation_invalid") { return false; }
        catch (Exception ex) when (FindSql(ex)?.Number == 1205) { return false; }
    }
    private static Microsoft.Data.SqlClient.SqlException? FindSql(Exception? ex) => ex is null ? null : ex as Microsoft.Data.SqlClient.SqlException ?? FindSql(ex.InnerException);
    private static (User, Tenant, Role) Seed(IfxDbContext db)
    {
        var tenant = Tenant.Create("Tenant", "test"); var role = Role.Create("Member", "test", tenant.Id);
        role.AddPermission(db.Permissions.Single(p => p.Name == "User:update"));
        var user = User.Create("Member", true); user.AddTenant(tenant); user.SetPrimaryTenant(tenant.Id); user.AddRole(role);
        return (user, tenant, role);
    }
    private sealed class Scope(Guid user, Guid tenant) : IExecutionContextAccessor
    {
        public bool HasCurrent => true;
        public ExecutionContextSnapshot Current { get; } = ExecutionContextSnapshot.ForTenant(Guid.NewGuid(), Guid.NewGuid(), null, tenant, "user", user.ToString(), "ifx", "test", 1);
    }
    private sealed class IndependentHttpAccessor : IHttpContextAccessor { public HttpContext? HttpContext { get; set; } }
    private static VerifiedIdentityFacts Facts(IfxDbContext db, Scope scope, Guid user, bool http)
    {
        var accessor = new IndependentHttpAccessor();
        if (http) accessor.HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
            new Claim("user_id", user.ToString()), new Claim("permission", "User:update"), new Claim("role", "PlatformAdmin"), new Claim("tenant", Guid.NewGuid().ToString()) }, "test")) };
        return new(new HttpIdentityFacts(accessor, scope), new ExecutionTenantSelection(scope), db);
    }
    private static async Task<List<string>> Audit(IfxDbContext db)
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root is not null && !File.Exists(Path.Combine(root.FullName, "IFX.sln"))) root = root.Parent;
        Assert.NotNull(root); await db.Database.OpenConnectionAsync();
        await using var cmd = db.Database.GetDbConnection().CreateCommand();
        cmd.CommandText = await File.ReadAllTextAsync(Path.Combine(root.FullName, "scripts/sql/plan05-membership-audit.sql"));
        await using var reader = await cmd.ExecuteReaderAsync(); var findings = new List<string>();
        while (await reader.ReadAsync()) findings.Add(reader.GetString(0));
        Assert.True(await reader.NextResultAsync()); var relations = 0;
        while (await reader.ReadAsync()) { Assert.True(reader.GetInt64(1) >= 0); relations++; }
        Assert.Equal(5, relations); return findings;
    }
    private static IfxDbContext Context(string connection) => new(new DbContextOptionsBuilder<IfxDbContext>().UseSqlServer(connection, sql => sql.MigrationsHistoryTable("__EFMigrationsHistory", "auth")).Options);
}

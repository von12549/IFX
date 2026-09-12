using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Infrastructure.Access;
using IFX.Modules.IAM.Infrastructure.Access.Repositories;
using IFX.Modules.IAM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

[Collection(SqlServerMigrationCollection.Name)]
public sealed class Plan05PolicySqlServerTests(SqlServerMigrationFixture fixture)
{
    [Fact]
    public async Task Existing_seed_policy_selection_uses_parsed_role_and_never_treats_role_policy_as_tenant_default()
    {
        var connection = await fixture.CreateDatabaseAsync("p05policy");
        await using var db = Context(connection);
        await db.Database.MigrateAsync();
        var repository = new PolicyDefinitionRepository(db);
        var defaultPolicy = await repository.GetPlatformAsync("user", "list");
        Assert.NotNull(defaultPolicy);
        Assert.DoesNotContain("GlobalRoleIncludes", defaultPolicy.ConditionsJson);
        var support = await repository.GetPlatformByGlobalRoleAsync("user", "list", "PlatformSupport");
        var auditor = await repository.GetPlatformByGlobalRoleAsync("user", "list", "PlatformAuditor");
        Assert.NotNull(support); Assert.NotNull(auditor); Assert.NotEqual(support.Id, auditor.Id);
        var originalRows = await db.PolicyDefinitions.AsNoTracking().Select(p => new { p.Id, p.ConditionsJson }).ToListAsync();
        var registry = new AbacTemplateRegistry(); BuiltInTemplates.Register(registry);
        var resolver = new DbAbacPolicyResolver(repository, registry, new StaticAbacPolicyResolver());
        Assert.Equal("platform-role-grant", (await resolver.ResolvePlatformPolicyForRoleAsync("user", "list", "PlatformSupport"))!.Classification);
        Assert.Equal(originalRows, await db.PolicyDefinitions.AsNoTracking().Select(p => new { p.Id, p.ConditionsJson }).ToListAsync());
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root is not null && !File.Exists(Path.Combine(root.FullName, "IFX.sln"))) root = root.Parent;
        Assert.NotNull(root);
        await db.Database.OpenConnectionAsync();
        await using var audit = db.Database.GetDbConnection().CreateCommand();
        audit.CommandText = await File.ReadAllTextAsync(Path.Combine(root.FullName, "scripts/sql/plan05-policy-classification-audit.sql"));
        await using var rows = await audit.ExecuteReaderAsync();
        var classified = 0;
        while (await rows.ReadAsync())
        {
            Assert.Contains(rows.GetString(rows.GetOrdinal("PolicyClass")), new[] { "tenant-custom", "platform-role-grant", "overridable-default" });
            Assert.Equal(64, rows.GetString(rows.GetOrdinal("OriginalPolicyHash")).Length);
            classified++;
        }
        Assert.Equal(originalRows.Count, classified);
    }

    [Fact]
    public async Task Whitespace_disabled_and_duplicate_rows_have_deterministic_fail_closed_selection()
    {
        var connection = await fixture.CreateDatabaseAsync("p05policystate");
        await using var db = Context(connection); await db.Database.MigrateAsync();
        var row = PolicyDefinition.Create(PolicyScope.Platform, null, "Role selector", "fund", "read",
            "[{ \"TemplateName\": \"GlobalRoleIncludes\", \"Parameters\": { \"global_role\": \"PlatformSupport\" } }]", null);
        db.PolicyDefinitions.Add(row); await db.SaveChangesAsync();
        var repo = new PolicyDefinitionRepository(db);
        Assert.Equal(row.Id, (await repo.GetPlatformByGlobalRoleAsync("fund", "read", "PlatformSupport"))!.Id);
        row.Deactivate(); await db.SaveChangesAsync();
        await using var second = Context(connection);
        var registry = new AbacTemplateRegistry(); BuiltInTemplates.Register(registry);
        var resolver = new DbAbacPolicyResolver(new PolicyDefinitionRepository(second), registry, new StaticAbacPolicyResolver());
        Assert.Equal(PolicyFailure.Disabled, (await Assert.ThrowsAsync<PolicyResolutionException>(() =>
            resolver.ResolvePlatformPolicyForRoleAsync("fund", "read", "PlatformSupport"))).Failure);
        db.PolicyDefinitions.Add(PolicyDefinition.Create(PolicyScope.Platform, null, "Duplicate", "fund", "read", row.ConditionsJson, null));
        await db.SaveChangesAsync();
        Assert.Equal(PolicyFailure.Invalid, (await Assert.ThrowsAsync<PolicyResolutionException>(() =>
            resolver.ResolvePlatformPolicyForRoleAsync("fund", "read", "PlatformSupport"))).Failure);
    }

    private static IfxDbContext Context(string connection) => new(new DbContextOptionsBuilder<IfxDbContext>()
        .UseSqlServer(connection, sql => sql.MigrationsHistoryTable("__EFMigrationsHistory", "auth")).Options);
}

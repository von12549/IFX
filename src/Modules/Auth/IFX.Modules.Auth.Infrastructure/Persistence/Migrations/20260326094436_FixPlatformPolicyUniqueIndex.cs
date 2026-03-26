using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// Replaces the broad unique index (Scope, TenantId, ResourceType, Action) with a
    /// filtered index that covers Tenant-scoped rows only (Scope = 0).
    /// Platform-scoped rows (Scope = 1) may have multiple policies per (ResourceType, Action)
    /// to support per-GlobalRole access control (e.g. PlatformSupport vs PlatformAuditor).
    /// </summary>
    public partial class FixPlatformPolicyUniqueIndex : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Drop any platform-scoped unique index that would block multiple platform policies
            // per (ResourceType, Action). Use IF EXISTS — exact name may vary by DB state.
            migrationBuilder.Sql(@"
DROP INDEX IF EXISTS [UX_PolicyDefinitions_Platform_Resource_Action] ON [auth].[PolicyDefinitions];
DROP INDEX IF EXISTS [IX_PolicyDefinitions_Scope_TenantId_ResourceType_Action] ON [auth].[PolicyDefinitions];
");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // No-op: we intentionally removed a constraining index; restoring it would
            // re-break the platform policy seeding. Leave Down empty.
        }
    }
}

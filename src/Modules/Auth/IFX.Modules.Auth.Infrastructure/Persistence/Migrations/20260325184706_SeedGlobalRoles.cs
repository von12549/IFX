using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedGlobalRoles : Migration
    {
        // Stable UUID v7 constants for seeded GlobalRoles (hardcoded — never change)
        private const string PlatformAdminId   = "0195d1a0-0000-7000-8000-000000000001";
        private const string PlatformSupportId = "0195d1a0-0000-7000-8000-000000000002";
        private const string PlatformAuditorId = "0195d1a0-0000-7000-8000-000000000003";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($"""
                INSERT INTO auth.GlobalRoles (Id, Name, Description, CreatedAt, UpdatedAt)
                SELECT '{PlatformAdminId}', 'PlatformAdmin', 'Full cross-tenant platform access', GETUTCDATE(), GETUTCDATE()
                WHERE NOT EXISTS (SELECT 1 FROM auth.GlobalRoles WHERE Id = '{PlatformAdminId}');

                INSERT INTO auth.GlobalRoles (Id, Name, Description, CreatedAt, UpdatedAt)
                SELECT '{PlatformSupportId}', 'PlatformSupport', 'Read-only cross-tenant support access', GETUTCDATE(), GETUTCDATE()
                WHERE NOT EXISTS (SELECT 1 FROM auth.GlobalRoles WHERE Id = '{PlatformSupportId}');

                INSERT INTO auth.GlobalRoles (Id, Name, Description, CreatedAt, UpdatedAt)
                SELECT '{PlatformAuditorId}', 'PlatformAuditor', 'Read-only audit access', GETUTCDATE(), GETUTCDATE()
                WHERE NOT EXISTS (SELECT 1 FROM auth.GlobalRoles WHERE Id = '{PlatformAuditorId}');
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($"""
                DELETE FROM auth.GlobalRoles
                WHERE Id IN ('{PlatformAdminId}', '{PlatformSupportId}', '{PlatformAuditorId}');
                """);
        }
    }
}

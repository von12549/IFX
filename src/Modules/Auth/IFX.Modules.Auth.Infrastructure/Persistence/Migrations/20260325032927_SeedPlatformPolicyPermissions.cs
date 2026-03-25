using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedPlatformPolicyPermissions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 1. Insert Platform.Policy.Read and Platform.Policy.Write permissions (idempotent)
            migrationBuilder.Sql("""
                DECLARE @now DATETIME2 = GETUTCDATE();
                INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], @now, @now
                FROM (VALUES
                    (NEWID(), 'Platform.Policy.Read',  'View platform-level ABAC policy definitions'),
                    (NEWID(), 'Platform.Policy.Write', 'Create/update/delete platform-level ABAC policy definitions')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])
                """);

            // 2. Assign both permissions to the Admin role (idempotent)
            migrationBuilder.Sql("""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] = 'Admin'
                  AND  p.[Name] IN ('Platform.Policy.Read', 'Platform.Policy.Write')
                  AND  NOT EXISTS (
                       SELECT 1 FROM [auth].[RolePermissions] rp
                       WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM [auth].[RolePermissions] WHERE [PermissionsId] IN (SELECT [Id] FROM [auth].[Permissions] WHERE [Name] IN ('Platform.Policy.Read', 'Platform.Policy.Write'))");
            migrationBuilder.Sql("DELETE FROM [auth].[Permissions] WHERE [Name] IN ('Platform.Policy.Read', 'Platform.Policy.Write')");
        }
    }
}

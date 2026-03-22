using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMultiTenantSupport : Migration
    {
        // Stable seed GUIDs
        private const string IFXTenantId    = "AAAAAAAA-0001-0000-0000-000000000001";
        private const string TestDeptId     = "AAAAAAAA-0002-0000-0000-000000000001";
        private const string AdminUserId    = "8314F7DA-2F5D-4128-A705-957CE0C3972E";
        private const string SeedDate       = "2026-03-22 00:00:00";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Roles_Name",
                schema: "auth",
                table: "Roles");

            migrationBuilder.DropIndex(
                name: "IX_RoleGroups_Name",
                schema: "auth",
                table: "RoleGroups");

            migrationBuilder.AddColumn<Guid>(
                name: "PrimaryTenantId",
                schema: "auth",
                table: "Users",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "TenantId",
                schema: "auth",
                table: "Roles",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "TenantId",
                schema: "auth",
                table: "RoleGroups",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "TenantId",
                schema: "auth",
                table: "Idps",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.CreateTable(
                name: "Tenants",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tenants", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Departments",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Departments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Departments_Tenants_TenantId",
                        column: x => x.TenantId,
                        principalSchema: "auth",
                        principalTable: "Tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserTenants",
                schema: "auth",
                columns: table => new
                {
                    TenantsId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserTenants", x => new { x.TenantsId, x.UserId });
                    table.ForeignKey(
                        name: "FK_UserTenants_Tenants_TenantsId",
                        column: x => x.TenantsId,
                        principalSchema: "auth",
                        principalTable: "Tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserTenants_Users_UserId",
                        column: x => x.UserId,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserDepartments",
                schema: "auth",
                columns: table => new
                {
                    DepartmentsId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserDepartments", x => new { x.DepartmentsId, x.UserId });
                    table.ForeignKey(
                        name: "FK_UserDepartments_Departments_DepartmentsId",
                        column: x => x.DepartmentsId,
                        principalSchema: "auth",
                        principalTable: "Departments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserDepartments_Users_UserId",
                        column: x => x.UserId,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_PrimaryTenantId",
                schema: "auth",
                table: "Users",
                column: "PrimaryTenantId");

            migrationBuilder.CreateIndex(
                name: "IX_Roles_TenantId_Name",
                schema: "auth",
                table: "Roles",
                columns: new[] { "TenantId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RoleGroups_TenantId_Name",
                schema: "auth",
                table: "RoleGroups",
                columns: new[] { "TenantId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Idps_TenantId",
                schema: "auth",
                table: "Idps",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_Departments_TenantId_Name",
                schema: "auth",
                table: "Departments",
                columns: new[] { "TenantId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Tenants_Name",
                schema: "auth",
                table: "Tenants",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserDepartments_UserId",
                schema: "auth",
                table: "UserDepartments",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserTenants_UserId",
                schema: "auth",
                table: "UserTenants",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Idps_Tenants_TenantId",
                schema: "auth",
                table: "Idps",
                column: "TenantId",
                principalSchema: "auth",
                principalTable: "Tenants",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_RoleGroups_Tenants_TenantId",
                schema: "auth",
                table: "RoleGroups",
                column: "TenantId",
                principalSchema: "auth",
                principalTable: "Tenants",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Roles_Tenants_TenantId",
                schema: "auth",
                table: "Roles",
                column: "TenantId",
                principalSchema: "auth",
                principalTable: "Tenants",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Users_Tenants_PrimaryTenantId",
                schema: "auth",
                table: "Users",
                column: "PrimaryTenantId",
                principalSchema: "auth",
                principalTable: "Tenants",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            // ── Seed data ──────────────────────────────────────────────────────────

            // 1. Seed the IFX Tenant
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Tenants] WHERE [Id] = '{IFXTenantId}')
                    INSERT INTO [auth].[Tenants] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                    VALUES ('{IFXTenantId}', 'IFX', 'Default IFX tenant', '{SeedDate}', '{SeedDate}')
                """);

            // 2. Backfill TenantId on Roles, RoleGroups, Idps to IFX tenant
            migrationBuilder.Sql($"""
                UPDATE [auth].[Roles]      SET [TenantId] = '{IFXTenantId}' WHERE [TenantId] = '00000000-0000-0000-0000-000000000000'
                """);
            migrationBuilder.Sql($"""
                UPDATE [auth].[RoleGroups] SET [TenantId] = '{IFXTenantId}' WHERE [TenantId] = '00000000-0000-0000-0000-000000000000'
                """);
            migrationBuilder.Sql($"""
                UPDATE [auth].[Idps]       SET [TenantId] = '{IFXTenantId}' WHERE [TenantId] = '00000000-0000-0000-0000-000000000000'
                """);

            // 3. Seed Test Department
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Departments] WHERE [Id] = '{TestDeptId}')
                    INSERT INTO [auth].[Departments] ([Id], [Name], [Description], [TenantId], [CreatedAt], [UpdatedAt])
                    VALUES ('{TestDeptId}', 'Test', 'Test department', '{IFXTenantId}', '{SeedDate}', '{SeedDate}')
                """);

            // 4. Seed Tenant and Department permissions
            migrationBuilder.Sql($"""
                DECLARE @now DATETIME2 = '{SeedDate}';
                INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], @now, @now
                FROM (VALUES
                    (NEWID(), 'Tenant.Read',      'View tenants'),
                    (NEWID(), 'Tenant.Write',     'Create/update/delete tenants'),
                    (NEWID(), 'Department.Read',  'View departments'),
                    (NEWID(), 'Department.Write', 'Create/update/delete departments')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])
                """);

            // 5. Assign new permissions to Admin role
            migrationBuilder.Sql($"""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] = 'Admin'
                  AND  p.[Name] IN ('Tenant.Read', 'Tenant.Write', 'Department.Read', 'Department.Write')
                  AND  NOT EXISTS (
                       SELECT 1 FROM [auth].[RolePermissions] rp
                       WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);

            // 6. Assign IFX Tenant to admin user and set as primary
            migrationBuilder.Sql($"""
                IF EXISTS (SELECT 1 FROM [auth].[Users] WHERE [Id] = '{AdminUserId}')
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [auth].[UserTenants] WHERE [UserId] = '{AdminUserId}' AND [TenantsId] = '{IFXTenantId}')
                        INSERT INTO [auth].[UserTenants] ([TenantsId], [UserId])
                        VALUES ('{IFXTenantId}', '{AdminUserId}');
                    UPDATE [auth].[Users] SET [PrimaryTenantId] = '{IFXTenantId}' WHERE [Id] = '{AdminUserId}'
                END
                """);

            // 7. Assign Test Department to admin user
            migrationBuilder.Sql($"""
                IF EXISTS (SELECT 1 FROM [auth].[Users] WHERE [Id] = '{AdminUserId}')
                AND NOT EXISTS (SELECT 1 FROM [auth].[UserDepartments] WHERE [UserId] = '{AdminUserId}' AND [DepartmentsId] = '{TestDeptId}')
                    INSERT INTO [auth].[UserDepartments] ([DepartmentsId], [UserId])
                    VALUES ('{TestDeptId}', '{AdminUserId}')
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Remove seed data before dropping tables
            migrationBuilder.Sql($"DELETE FROM [auth].[UserDepartments] WHERE [DepartmentsId] = '{TestDeptId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserTenants]     WHERE [TenantsId]     = '{IFXTenantId}'");
            migrationBuilder.Sql($"UPDATE [auth].[Users] SET [PrimaryTenantId] = NULL WHERE [PrimaryTenantId] = '{IFXTenantId}'");
            migrationBuilder.Sql("DELETE FROM [auth].[RolePermissions] WHERE [PermissionsId] IN (SELECT [Id] FROM [auth].[Permissions] WHERE [Name] IN ('Tenant.Read', 'Tenant.Write', 'Department.Read', 'Department.Write'))");
            migrationBuilder.Sql("DELETE FROM [auth].[Permissions] WHERE [Name] IN ('Tenant.Read', 'Tenant.Write', 'Department.Read', 'Department.Write')");

            migrationBuilder.DropForeignKey(
                name: "FK_Idps_Tenants_TenantId",
                schema: "auth",
                table: "Idps");

            migrationBuilder.DropForeignKey(
                name: "FK_RoleGroups_Tenants_TenantId",
                schema: "auth",
                table: "RoleGroups");

            migrationBuilder.DropForeignKey(
                name: "FK_Roles_Tenants_TenantId",
                schema: "auth",
                table: "Roles");

            migrationBuilder.DropForeignKey(
                name: "FK_Users_Tenants_PrimaryTenantId",
                schema: "auth",
                table: "Users");

            migrationBuilder.DropTable(
                name: "UserDepartments",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserTenants",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Departments",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Tenants",
                schema: "auth");

            migrationBuilder.DropIndex(
                name: "IX_Users_PrimaryTenantId",
                schema: "auth",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Roles_TenantId_Name",
                schema: "auth",
                table: "Roles");

            migrationBuilder.DropIndex(
                name: "IX_RoleGroups_TenantId_Name",
                schema: "auth",
                table: "RoleGroups");

            migrationBuilder.DropIndex(
                name: "IX_Idps_TenantId",
                schema: "auth",
                table: "Idps");

            migrationBuilder.DropColumn(
                name: "PrimaryTenantId",
                schema: "auth",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TenantId",
                schema: "auth",
                table: "Roles");

            migrationBuilder.DropColumn(
                name: "TenantId",
                schema: "auth",
                table: "RoleGroups");

            migrationBuilder.DropColumn(
                name: "TenantId",
                schema: "auth",
                table: "Idps");

            migrationBuilder.CreateIndex(
                name: "IX_Roles_Name",
                schema: "auth",
                table: "Roles",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RoleGroups_Name",
                schema: "auth",
                table: "RoleGroups",
                column: "Name",
                unique: true);
        }
    }
}

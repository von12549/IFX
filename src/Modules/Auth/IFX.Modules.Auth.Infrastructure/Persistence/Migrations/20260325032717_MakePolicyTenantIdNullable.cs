using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class MakePolicyTenantIdNullable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_PolicyDefinitions_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions");

            migrationBuilder.AlterColumn<Guid>(
                name: "TenantId",
                schema: "auth",
                table: "PolicyDefinitions",
                type: "uniqueidentifier",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier");

            migrationBuilder.CreateIndex(
                name: "UX_PolicyDefinitions_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions",
                columns: new[] { "TenantId", "ResourceType", "Action" },
                unique: true,
                filter: "[TenantId] IS NOT NULL");

            // Separate filtered unique index for platform rows (TenantId IS NULL).
            // EF's nullable unique index excludes NULLs, so we add this index explicitly
            // to enforce at most one platform row per (ResourceType, Action).
            migrationBuilder.Sql("""
                CREATE UNIQUE INDEX [UX_PolicyDefinitions_Platform_Resource_Action]
                ON [auth].[PolicyDefinitions] ([ResourceType], [Action])
                WHERE [TenantId] IS NULL
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP INDEX IF EXISTS [UX_PolicyDefinitions_Platform_Resource_Action] ON [auth].[PolicyDefinitions]");

            migrationBuilder.DropIndex(
                name: "UX_PolicyDefinitions_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions");

            migrationBuilder.AlterColumn<Guid>(
                name: "TenantId",
                schema: "auth",
                table: "PolicyDefinitions",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "UX_PolicyDefinitions_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions",
                columns: new[] { "TenantId", "ResourceType", "Action" },
                unique: true);
        }
    }
}

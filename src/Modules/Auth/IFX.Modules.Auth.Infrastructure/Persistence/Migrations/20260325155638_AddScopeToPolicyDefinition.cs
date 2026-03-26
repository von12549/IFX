using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddScopeToPolicyDefinition : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_PolicyDefinitions_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions");

            migrationBuilder.AddColumn<int>(
                name: "Scope",
                schema: "auth",
                table: "PolicyDefinitions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Backfill: existing rows with TenantId IS NULL are platform-level (Scope = 1)
            migrationBuilder.Sql(
                "UPDATE auth.PolicyDefinitions SET Scope = 1 WHERE TenantId IS NULL");

            migrationBuilder.CreateIndex(
                name: "UX_PolicyDefinitions_Scope_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions",
                columns: new[] { "Scope", "TenantId", "ResourceType", "Action" },
                unique: true,
                filter: "[TenantId] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_PolicyDefinitions_Scope_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions");

            migrationBuilder.DropColumn(
                name: "Scope",
                schema: "auth",
                table: "PolicyDefinitions");

            migrationBuilder.CreateIndex(
                name: "UX_PolicyDefinitions_Tenant_Resource_Action",
                schema: "auth",
                table: "PolicyDefinitions",
                columns: new[] { "TenantId", "ResourceType", "Action" },
                unique: true,
                filter: "[TenantId] IS NOT NULL");
        }
    }
}

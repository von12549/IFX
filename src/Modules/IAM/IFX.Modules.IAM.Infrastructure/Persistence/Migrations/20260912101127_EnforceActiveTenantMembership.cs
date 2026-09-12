using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.IAM.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class EnforceActiveTenantMembership : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                schema: "auth",
                table: "Tenants",
                type: "bit",
                nullable: false,
                defaultValue: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsActive",
                schema: "auth",
                table: "Tenants");
        }
    }
}

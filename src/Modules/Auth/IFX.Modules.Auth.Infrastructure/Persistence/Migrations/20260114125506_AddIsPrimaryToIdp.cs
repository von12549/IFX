using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddIsPrimaryToIdp : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsPrimary",
                schema: "auth",
                table: "Idps",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Idps_IsPrimary",
                schema: "auth",
                table: "Idps",
                column: "IsPrimary",
                unique: true,
                filter: "[IsPrimary] = 1");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Idps_IsPrimary",
                schema: "auth",
                table: "Idps");

            migrationBuilder.DropColumn(
                name: "IsPrimary",
                schema: "auth",
                table: "Idps");
        }
    }
}

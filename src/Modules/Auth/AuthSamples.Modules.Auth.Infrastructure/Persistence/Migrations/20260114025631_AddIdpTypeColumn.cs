using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddIdpTypeColumn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "IdpType",
                schema: "auth",
                table: "Idps",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Internal");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IdpType",
                schema: "auth",
                table: "Idps");
        }
    }
}

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddIssuerToUsers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Issuer",
                schema: "cognito",
                table: "Users",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Issuer",
                schema: "cognito",
                table: "Users");
        }
    }
}

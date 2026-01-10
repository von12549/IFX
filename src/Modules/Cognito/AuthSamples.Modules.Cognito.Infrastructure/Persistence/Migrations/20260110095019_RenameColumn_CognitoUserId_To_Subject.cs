using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RenameColumn_CognitoUserId_To_Subject : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "CognitoUserId",
                schema: "cognito",
                table: "Users",
                newName: "Subject");

            migrationBuilder.RenameIndex(
                name: "IX_Users_CognitoUserId",
                schema: "cognito",
                table: "Users",
                newName: "IX_Users_Subject");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Subject",
                schema: "cognito",
                table: "Users",
                newName: "CognitoUserId");

            migrationBuilder.RenameIndex(
                name: "IX_Users_Subject",
                schema: "cognito",
                table: "Users",
                newName: "IX_Users_CognitoUserId");
        }
    }
}

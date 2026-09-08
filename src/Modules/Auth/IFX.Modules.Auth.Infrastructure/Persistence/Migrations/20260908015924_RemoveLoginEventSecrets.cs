using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemoveLoginEventSecrets : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AccessToken",
                schema: "auth",
                table: "LoginEvents");

            migrationBuilder.DropColumn(
                name: "CognitoSessionId",
                schema: "auth",
                table: "LoginEvents");

            migrationBuilder.DropColumn(
                name: "RefreshToken",
                schema: "auth",
                table: "LoginEvents");

            migrationBuilder.DropColumn(
                name: "TokenExpiresAt",
                schema: "auth",
                table: "LoginEvents");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            throw new NotSupportedException(
                "This security remediation is roll-forward only; secret persistence must not be restored.");
        }
    }
}

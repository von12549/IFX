using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSsoUserRole : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            var ssoUserRoleId = Guid.NewGuid();
            var now = DateTime.UtcNow;

            migrationBuilder.InsertData(
                schema: "cognito",
                table: "UserRoles",
                columns: new[] { "Id", "RoleName", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[]
                {
                    ssoUserRoleId,
                    "SsoUser",
                    "User authenticated via SSO provider",
                    now,
                    now
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                schema: "cognito",
                table: "UserRoles",
                keyColumn: "RoleName",
                keyValue: "SsoUser");
        }
    }
}

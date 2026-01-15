using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPendingRole : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            var pendingRoleId = Guid.NewGuid();
            var now = DateTime.UtcNow;

            migrationBuilder.InsertData(
                schema: "auth",
                table: "UserRoles",
                columns: new[] { "Id", "RoleName", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[]
                {
                    pendingRoleId,
                    "Pending",
                    "User with incomplete registration, requires profile completion",
                    now,
                    now
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                schema: "auth",
                table: "UserRoles",
                keyColumn: "RoleName",
                keyValue: "Pending");
        }
    }
}

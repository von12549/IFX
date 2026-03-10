using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddUserRoles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Step 1: Create UserRoles table
            migrationBuilder.CreateTable(
                name: "UserRoles",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoleName = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserRoles", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_RoleName",
                schema: "cognito",
                table: "UserRoles",
                column: "RoleName",
                unique: true);

            // Step 2: Insert seed data for Admin and User roles
            var adminRoleId = Guid.NewGuid();
            var userRoleId = Guid.NewGuid();
            var now = DateTime.UtcNow;

            migrationBuilder.InsertData(
                schema: "cognito",
                table: "UserRoles",
                columns: new[] { "Id", "RoleName", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[,]
                {
                    { adminRoleId, "Admin", "Administrator with full system access", now, now },
                    { userRoleId, "User", "Standard user with limited permissions", now, now }
                });

            // Step 3: Add UserRoleId column to Users table (nullable initially)
            migrationBuilder.AddColumn<Guid>(
                name: "UserRoleId",
                schema: "cognito",
                table: "Users",
                type: "uniqueidentifier",
                nullable: true);

            // Step 4: Update all existing users to have the "User" role
            migrationBuilder.Sql($"UPDATE cognito.Users SET UserRoleId = '{userRoleId}'");

            // Step 5: Alter UserRoleId column to NOT NULL
            migrationBuilder.AlterColumn<Guid>(
                name: "UserRoleId",
                schema: "cognito",
                table: "Users",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            // Step 6: Create index and foreign key constraint
            migrationBuilder.CreateIndex(
                name: "IX_Users_UserRoleId",
                schema: "cognito",
                table: "Users",
                column: "UserRoleId");

            migrationBuilder.AddForeignKey(
                name: "FK_Users_UserRoles_UserRoleId",
                schema: "cognito",
                table: "Users",
                column: "UserRoleId",
                principalSchema: "cognito",
                principalTable: "UserRoles",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Users_UserRoles_UserRoleId",
                schema: "cognito",
                table: "Users");

            migrationBuilder.DropTable(
                name: "UserRoles",
                schema: "cognito");

            migrationBuilder.DropIndex(
                name: "IX_Users_UserRoleId",
                schema: "cognito",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "UserRoleId",
                schema: "cognito",
                table: "Users");
        }
    }
}

using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "cognito");

            migrationBuilder.CreateTable(
                name: "LoginEvents",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LoginTimestamp = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Success = table.Column<bool>(type: "bit", nullable: false),
                    FailureReason = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    IpAddress = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: false),
                    DeviceBrowser = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    DeviceOS = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    DeviceType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    IsBot = table.Column<bool>(type: "bit", nullable: false),
                    UserAgent = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    CognitoSessionId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    AccessToken = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true),
                    RefreshToken = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true),
                    TokenExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LoginEvents", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "LogoutEvents",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LogoutTimestamp = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SessionDuration = table.Column<TimeSpan>(type: "time", nullable: false),
                    IpAddress = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LogoutEvents", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RegistrationFlowEvents",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Email = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    Username = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    RegistrationInitiatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RegistrationConfirmedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Status = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    ConfirmationCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    FailureReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IpAddress = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegistrationFlowEvents", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserActivityLogs",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActivityType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Timestamp = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IpAddress = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: false),
                    Metadata = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserActivityLogs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CognitoUserId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    Username = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    FirstName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    LastName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    EmailVerified = table.Column<bool>(type: "bit", nullable: false),
                    PhoneNumberVerified = table.Column<bool>(type: "bit", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    LastSyncedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_LoginTimestamp",
                schema: "cognito",
                table: "LoginEvents",
                column: "LoginTimestamp");

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_UserId",
                schema: "cognito",
                table: "LoginEvents",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_UserId_LoginTimestamp",
                schema: "cognito",
                table: "LoginEvents",
                columns: new[] { "UserId", "LoginTimestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_LogoutEvents_LogoutTimestamp",
                schema: "cognito",
                table: "LogoutEvents",
                column: "LogoutTimestamp");

            migrationBuilder.CreateIndex(
                name: "IX_LogoutEvents_UserId",
                schema: "cognito",
                table: "LogoutEvents",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationFlowEvents_Email",
                schema: "cognito",
                table: "RegistrationFlowEvents",
                column: "Email");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationFlowEvents_RegistrationInitiatedAt",
                schema: "cognito",
                table: "RegistrationFlowEvents",
                column: "RegistrationInitiatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationFlowEvents_Status",
                schema: "cognito",
                table: "RegistrationFlowEvents",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivityLogs_Timestamp",
                schema: "cognito",
                table: "UserActivityLogs",
                column: "Timestamp");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivityLogs_UserId",
                schema: "cognito",
                table: "UserActivityLogs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivityLogs_UserId_Timestamp",
                schema: "cognito",
                table: "UserActivityLogs",
                columns: new[] { "UserId", "Timestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_Users_CognitoUserId",
                schema: "cognito",
                table: "Users",
                column: "CognitoUserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                schema: "cognito",
                table: "Users",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Username",
                schema: "cognito",
                table: "Users",
                column: "Username",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LoginEvents",
                schema: "cognito");

            migrationBuilder.DropTable(
                name: "LogoutEvents",
                schema: "cognito");

            migrationBuilder.DropTable(
                name: "RegistrationFlowEvents",
                schema: "cognito");

            migrationBuilder.DropTable(
                name: "UserActivityLogs",
                schema: "cognito");

            migrationBuilder.DropTable(
                name: "Users",
                schema: "cognito");
        }
    }
}

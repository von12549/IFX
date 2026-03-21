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
                name: "auth");

            migrationBuilder.CreateTable(
                name: "Idps",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Issuer = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    LoginUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    IdpType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false, defaultValue: "Internal"),
                    IsPrimary = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Enabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    AutoProvisionEnabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    Authority = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    ExpectedAudiences = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false, defaultValue: "[]"),
                    AllowedAlgs = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, defaultValue: "[]"),
                    RequiredScopes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false, defaultValue: "[]"),
                    ClaimMapping = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false, defaultValue: "{}"),
                    ClockSkewSeconds = table.Column<int>(type: "int", nullable: false, defaultValue: 300),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Idps", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "LoginEvents",
                schema: "auth",
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
                schema: "auth",
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
                schema: "auth",
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
                schema: "auth",
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
                name: "UserRoles",
                schema: "auth",
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

            migrationBuilder.CreateTable(
                name: "Users",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    UserRoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DisplayName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Users_UserRoles_UserRoleId",
                        column: x => x.UserRoleId,
                        principalSchema: "auth",
                        principalTable: "UserRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserIdentities",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IdpId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Issuer = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    FirstName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    LastName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    BirthDate = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    EmailVerified = table.Column<bool>(type: "bit", nullable: false),
                    PhoneNumberVerified = table.Column<bool>(type: "bit", nullable: false),
                    LastSyncedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Email = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    Subject = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserIdentities", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserIdentities_Idps_IdpId",
                        column: x => x.IdpId,
                        principalSchema: "auth",
                        principalTable: "Idps",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserIdentities_Users_UserId",
                        column: x => x.UserId,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "EmailVerificationTokens",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserIdentityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    TokenHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Code = table.Column<string>(type: "nvarchar(6)", maxLength: 6, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsUsed = table.Column<bool>(type: "bit", nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EmailVerificationTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_EmailVerificationTokens_UserIdentities_UserIdentityId",
                        column: x => x.UserIdentityId,
                        principalSchema: "auth",
                        principalTable: "UserIdentities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationTokens_ExpiresAt",
                schema: "auth",
                table: "EmailVerificationTokens",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationTokens_UserIdentityId",
                schema: "auth",
                table: "EmailVerificationTokens",
                column: "UserIdentityId");

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationTokens_UserIdentityId_Code",
                schema: "auth",
                table: "EmailVerificationTokens",
                columns: new[] { "UserIdentityId", "Code" });

            migrationBuilder.CreateIndex(
                name: "UQ_EmailVerificationTokens_TokenHash",
                schema: "auth",
                table: "EmailVerificationTokens",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Idps_Enabled",
                schema: "auth",
                table: "Idps",
                column: "Enabled");

            migrationBuilder.CreateIndex(
                name: "IX_Idps_IsPrimary",
                schema: "auth",
                table: "Idps",
                column: "IsPrimary",
                unique: true,
                filter: "[IsPrimary] = 1");

            migrationBuilder.CreateIndex(
                name: "IX_Idps_Issuer",
                schema: "auth",
                table: "Idps",
                column: "Issuer",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_LoginTimestamp",
                schema: "auth",
                table: "LoginEvents",
                column: "LoginTimestamp");

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_UserId",
                schema: "auth",
                table: "LoginEvents",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_UserId_LoginTimestamp",
                schema: "auth",
                table: "LoginEvents",
                columns: new[] { "UserId", "LoginTimestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_LogoutEvents_LogoutTimestamp",
                schema: "auth",
                table: "LogoutEvents",
                column: "LogoutTimestamp");

            migrationBuilder.CreateIndex(
                name: "IX_LogoutEvents_UserId",
                schema: "auth",
                table: "LogoutEvents",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationFlowEvents_Email",
                schema: "auth",
                table: "RegistrationFlowEvents",
                column: "Email");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationFlowEvents_RegistrationInitiatedAt",
                schema: "auth",
                table: "RegistrationFlowEvents",
                column: "RegistrationInitiatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationFlowEvents_Status",
                schema: "auth",
                table: "RegistrationFlowEvents",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivityLogs_Timestamp",
                schema: "auth",
                table: "UserActivityLogs",
                column: "Timestamp");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivityLogs_UserId",
                schema: "auth",
                table: "UserActivityLogs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserActivityLogs_UserId_Timestamp",
                schema: "auth",
                table: "UserActivityLogs",
                columns: new[] { "UserId", "Timestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_UserIdentities_IdpId",
                schema: "auth",
                table: "UserIdentities",
                column: "IdpId");

            migrationBuilder.CreateIndex(
                name: "IX_UserIdentities_UserId",
                schema: "auth",
                table: "UserIdentities",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "UQ_UserIdentity_Issuer_Subject",
                schema: "auth",
                table: "UserIdentities",
                columns: new[] { "Issuer", "Subject" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_RoleName",
                schema: "auth",
                table: "UserRoles",
                column: "RoleName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_UserRoleId",
                schema: "auth",
                table: "Users",
                column: "UserRoleId");

            // Seed UserRoles
            var seedDate = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            migrationBuilder.InsertData(
                schema: "auth",
                table: "UserRoles",
                columns: new[] { "Id", "RoleName", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[,]
                {
                    { new Guid("a1b2c3d4-0001-0000-0000-000000000001"), "Admin",   "Administrator role",                                            seedDate, seedDate },
                    { new Guid("a1b2c3d4-0001-0000-0000-000000000002"), "User",    "Standard user role",                                            seedDate, seedDate },
                    { new Guid("a1b2c3d4-0001-0000-0000-000000000003"), "SsoUser", "User authenticated via SSO provider",                           seedDate, seedDate },
                    { new Guid("a1b2c3d4-0001-0000-0000-000000000004"), "Pending", "User with incomplete registration, requires profile completion", seedDate, seedDate },
                });

            // Seed Idps
            migrationBuilder.InsertData(
                schema: "auth",
                table: "Idps",
                columns: new[] { "Id", "Name", "Issuer", "Authority", "Description", "LoginUrl", "IdpType", "IsPrimary", "Enabled", "AutoProvisionEnabled", "ExpectedAudiences", "AllowedAlgs", "RequiredScopes", "ClaimMapping", "ClockSkewSeconds", "CreatedAt", "UpdatedAt" },
                values: new object[,]
                {
                    {
                        new Guid("b1b2c3d4-0002-0000-0000-000000000001"),
                        "IFX Cognito",
                        "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi",
                        "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi",
                        "IFX AWS Cognito Identity Provider",
                        "", "Internal", true, true, true,
                        "[]", "[]", "[]", "{}", 300,
                        seedDate, seedDate
                    },
                    {
                        new Guid("b1b2c3d4-0002-0000-0000-000000000002"),
                        "Test External Idp",
                        "https://test-external-idp.example.com",
                        "https://test-external-idp.example.com",
                        "External Identity Provider",
                        "https://test-external-idp.example.com/login",
                        "External", false, false, false,
                        "[]", "[]", "[]", "{}", 300,
                        seedDate, seedDate
                    },
                    {
                        new Guid("b1b2c3d4-0002-0000-0000-000000000003"),
                        "VON Cognito Idp",
                        "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P",
                        "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P",
                        "VON's Private Cognito Identity Provider",
                        "", "External", false, true, true,
                        "[]", "[]", "[]", "{}", 300,
                        seedDate, seedDate
                    },
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(schema: "auth", table: "Idps", keyColumn: "Id", keyValue: new Guid("b1b2c3d4-0002-0000-0000-000000000001"));
            migrationBuilder.DeleteData(schema: "auth", table: "Idps", keyColumn: "Id", keyValue: new Guid("b1b2c3d4-0002-0000-0000-000000000002"));
            migrationBuilder.DeleteData(schema: "auth", table: "Idps", keyColumn: "Id", keyValue: new Guid("b1b2c3d4-0002-0000-0000-000000000003"));
            migrationBuilder.DeleteData(schema: "auth", table: "UserRoles", keyColumn: "Id", keyValue: new Guid("a1b2c3d4-0001-0000-0000-000000000001"));
            migrationBuilder.DeleteData(schema: "auth", table: "UserRoles", keyColumn: "Id", keyValue: new Guid("a1b2c3d4-0001-0000-0000-000000000002"));
            migrationBuilder.DeleteData(schema: "auth", table: "UserRoles", keyColumn: "Id", keyValue: new Guid("a1b2c3d4-0001-0000-0000-000000000003"));
            migrationBuilder.DeleteData(schema: "auth", table: "UserRoles", keyColumn: "Id", keyValue: new Guid("a1b2c3d4-0001-0000-0000-000000000004"));

            migrationBuilder.DropTable(
                name: "EmailVerificationTokens",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "LoginEvents",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "LogoutEvents",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "RegistrationFlowEvents",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserActivityLogs",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserIdentities",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Idps",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Users",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserRoles",
                schema: "auth");
        }
    }
}

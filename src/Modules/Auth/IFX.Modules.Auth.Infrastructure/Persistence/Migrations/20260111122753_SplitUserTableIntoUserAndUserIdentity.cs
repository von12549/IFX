using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SplitUserTableIntoUserAndUserIdentity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // STEP 1: Rename old Users table to UsersBackup using raw SQL to avoid constraint conflicts
            migrationBuilder.Sql("EXEC sp_rename 'auth.Users', 'UsersBackup'");

            // Drop constraints from UsersBackup that would conflict
            migrationBuilder.Sql(@"
                ALTER TABLE [auth].[UsersBackup] DROP CONSTRAINT [PK_Users];
                ALTER TABLE [auth].[UsersBackup] DROP CONSTRAINT [FK_Users_UserRoles_UserRoleId];
                DROP INDEX IF EXISTS [IX_Users_Email] ON [auth].[UsersBackup];
                DROP INDEX IF EXISTS [IX_Users_Subject] ON [auth].[UsersBackup];
                DROP INDEX IF EXISTS [IX_Users_Username] ON [auth].[UsersBackup];
                DROP INDEX IF EXISTS [IX_Users_UserRoleId] ON [auth].[UsersBackup];
            ");

            // STEP 2: Create new Users table with simplified structure
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

            migrationBuilder.CreateIndex(
                name: "IX_Users_UserRoleId",
                schema: "auth",
                table: "Users",
                column: "UserRoleId");

            // STEP 3: Create UserIdentities table
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

            // STEP 4: Migrate data from UsersBackup to new Users and UserIdentities tables
            migrationBuilder.Sql(@"
                -- Get IFX Cognito IdP ID
                DECLARE @IfxCognitoIdpId UNIQUEIDENTIFIER;
                SELECT @IfxCognitoIdpId = Id FROM [auth].[Idps]
                WHERE Issuer = 'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P';

                -- Populate new Users table (simplified structure)
                INSERT INTO [auth].[Users] (Id, IsActive, UserRoleId, DisplayName, CreatedAt, UpdatedAt)
                SELECT Id, IsActive, UserRoleId, CONCAT(FirstName, ' ', LastName), CreatedAt, UpdatedAt
                FROM [auth].[UsersBackup];

                -- Populate UserIdentities table (all identity data)
                INSERT INTO [auth].[UserIdentities] (
                    Id, UserId, IdpId, Issuer, Subject, Email,
                    FirstName, LastName, BirthDate, PhoneNumber,
                    EmailVerified, PhoneNumberVerified, LastSyncedAt,
                    CreatedAt, UpdatedAt
                )
                SELECT
                    NEWID(), Id, @IfxCognitoIdpId, Issuer, Subject, Email,
                    FirstName, LastName, BirthDate, PhoneNumber,
                    EmailVerified, PhoneNumberVerified, LastSyncedAt,
                    CreatedAt, UpdatedAt
                FROM [auth].[UsersBackup];
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // ROLLBACK: Drop new tables
            migrationBuilder.DropTable(
                name: "UserIdentities",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Users",
                schema: "auth");

            // ROLLBACK: Restore UsersBackup to Users
            migrationBuilder.Sql("EXEC sp_rename 'auth.UsersBackup', 'Users'");

            // ROLLBACK: Restore constraints to Users table
            migrationBuilder.Sql(@"
                ALTER TABLE [auth].[Users] ADD CONSTRAINT [PK_Users] PRIMARY KEY ([Id]);
                ALTER TABLE [auth].[Users] ADD CONSTRAINT [FK_Users_UserRoles_UserRoleId]
                    FOREIGN KEY ([UserRoleId]) REFERENCES [auth].[UserRoles]([Id]);
                CREATE UNIQUE INDEX [IX_Users_Email] ON [auth].[Users]([Email]);
                CREATE UNIQUE INDEX [IX_Users_Subject] ON [auth].[Users]([Subject]);
                CREATE UNIQUE INDEX [IX_Users_Username] ON [auth].[Users]([Username]);
                CREATE INDEX [IX_Users_UserRoleId] ON [auth].[Users]([UserRoleId]);
            ");

            // NOTE: This Down() method assumes UsersBackup still exists.
            // If UsersBackup was already dropped in Phase 2.12, rollback is not possible.
        }

        /// <inheritdoc />
        protected void OriginalDown(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserIdentities",
                schema: "auth");

            migrationBuilder.DropColumn(
                name: "DisplayName",
                schema: "auth",
                table: "Users");

            migrationBuilder.AddColumn<string>(
                name: "BirthDate",
                schema: "auth",
                table: "Users",
                type: "nvarchar(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Email",
                schema: "auth",
                table: "Users",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "EmailVerified",
                schema: "auth",
                table: "Users",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "FirstName",
                schema: "auth",
                table: "Users",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Issuer",
                schema: "auth",
                table: "Users",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P");

            migrationBuilder.AddColumn<string>(
                name: "LastName",
                schema: "auth",
                table: "Users",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                schema: "auth",
                table: "Users",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "PhoneNumber",
                schema: "auth",
                table: "Users",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "PhoneNumberVerified",
                schema: "auth",
                table: "Users",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "Subject",
                schema: "auth",
                table: "Users",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Username",
                schema: "auth",
                table: "Users",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                schema: "auth",
                table: "Users",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Subject",
                schema: "auth",
                table: "Users",
                column: "Subject",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Username",
                schema: "auth",
                table: "Users",
                column: "Username",
                unique: true);
        }
    }
}

using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddIdpTable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Idps",
                schema: "cognito",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Issuer = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    LoginUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
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

            migrationBuilder.CreateIndex(
                name: "IX_Idps_Enabled",
                schema: "cognito",
                table: "Idps",
                column: "Enabled");

            migrationBuilder.CreateIndex(
                name: "IX_Idps_Issuer",
                schema: "cognito",
                table: "Idps",
                column: "Issuer",
                unique: true);

            // Seed data for IFX Cognito IdP
            var ifxCognitoId = Guid.NewGuid();
            var now = DateTime.UtcNow;

            migrationBuilder.InsertData(
                schema: "cognito",
                table: "Idps",
                columns: new[]
                {
                    "Id", "Name", "Issuer", "Authority", "Description",
                    "LoginUrl", "Enabled", "AutoProvisionEnabled",
                    "ExpectedAudiences", "AllowedAlgs", "RequiredScopes",
                    "ClaimMapping", "ClockSkewSeconds",
                    "CreatedAt", "UpdatedAt"
                },
                values: new object[]
                {
                    ifxCognitoId,
                    "IFX Cognito",
                    "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P",
                    "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P",
                    "Primary AWS Cognito Identity Provider for IFX",
                    "", // LoginUrl empty for now
                    true, // Enabled
                    true, // AutoProvisionEnabled
                    "[]", // ExpectedAudiences
                    "[]", // AllowedAlgs
                    "[]", // RequiredScopes
                    "{}", // ClaimMapping
                    300, // ClockSkewSeconds
                    now,
                    now
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                schema: "cognito",
                table: "Idps",
                keyColumn: "Issuer",
                keyValue: "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P");

            migrationBuilder.DropTable(
                name: "Idps",
                schema: "cognito");
        }
    }
}

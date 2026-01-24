using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddEmailVerificationToken : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "EmailVerificationTokens",
                schema: "auth");
        }
    }
}

using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Holdings.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "holdings");

            migrationBuilder.CreateTable(
                name: "Holdings",
                schema: "holdings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestmentAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ClassId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Units = table.Column<decimal>(type: "decimal(18,8)", precision: 18, scale: 8, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    LastTransactionAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Holdings", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Holdings_TenantId",
                schema: "holdings",
                table: "Holdings",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_Holdings_TenantId_ClassId",
                schema: "holdings",
                table: "Holdings",
                columns: new[] { "TenantId", "ClassId" });

            migrationBuilder.CreateIndex(
                name: "IX_Holdings_TenantId_InvestmentAccountId_ClassId",
                schema: "holdings",
                table: "Holdings",
                columns: new[] { "TenantId", "InvestmentAccountId", "ClassId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Holdings",
                schema: "holdings");
        }
    }
}

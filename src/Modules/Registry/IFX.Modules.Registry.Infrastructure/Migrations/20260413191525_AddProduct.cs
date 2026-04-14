using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Registry.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddProduct : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ProductId",
                schema: "registry",
                table: "Funds",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Products",
                schema: "registry",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    ProductName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ProductType = table.Column<int>(type: "int", nullable: false),
                    BaseCurrency = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false),
                    ApirCode = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true),
                    Isin = table.Column<string>(type: "nvarchar(12)", maxLength: 12, nullable: true),
                    RegulatorSchemeNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    PdsReference = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IssuerName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    InceptionDate = table.Column<DateOnly>(type: "date", nullable: false),
                    WindUpDate = table.Column<DateOnly>(type: "date", nullable: true),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Products", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Funds_ProductId",
                schema: "registry",
                table: "Funds",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_Products_TenantId_ProductCode",
                schema: "registry",
                table: "Products",
                columns: new[] { "TenantId", "ProductCode" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Funds_Products_ProductId",
                schema: "registry",
                table: "Funds",
                column: "ProductId",
                principalSchema: "registry",
                principalTable: "Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Funds_Products_ProductId",
                schema: "registry",
                table: "Funds");

            migrationBuilder.DropTable(
                name: "Products",
                schema: "registry");

            migrationBuilder.DropIndex(
                name: "IX_Funds_ProductId",
                schema: "registry",
                table: "Funds");

            migrationBuilder.DropColumn(
                name: "ProductId",
                schema: "registry",
                table: "Funds");
        }
    }
}

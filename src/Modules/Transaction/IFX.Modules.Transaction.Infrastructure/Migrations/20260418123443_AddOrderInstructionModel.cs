using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Transaction.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddOrderInstructionModel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ChargeDetails",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CommissionDetails",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Currency",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(3)",
                maxLength: 3,
                nullable: false,
                defaultValue: "AUD");

            migrationBuilder.AddColumn<string>(
                name: "ExternalFundId",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(35)",
                maxLength: 35,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExternalFundIdOtherType",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(35)",
                maxLength: 35,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExternalFundIdType",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(10)",
                maxLength: 10,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LegId",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(35)",
                maxLength: 35,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "OrderId",
                schema: "transaction",
                table: "Transactions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PriceAmount",
                schema: "transaction",
                table: "Transactions",
                type: "decimal(18,8)",
                precision: 18,
                scale: 8,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PriceCurrency",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(3)",
                maxLength: 3,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PriceType",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(35)",
                maxLength: 35,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TaxDetails",
                schema: "transaction",
                table: "Transactions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Orders",
                schema: "transaction",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OrderReference = table.Column<string>(type: "nvarchar(35)", maxLength: 35, nullable: false),
                    DealReference = table.Column<string>(type: "nvarchar(350)", maxLength: 350, nullable: true),
                    OrderType = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    RejectionReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ExpectedTradeDate = table.Column<DateOnly>(type: "date", nullable: true),
                    ExpectedSettlementDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Orders", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_OrderId",
                schema: "transaction",
                table: "Transactions",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_TenantId",
                schema: "transaction",
                table: "Orders",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_TenantId_OrderReference",
                schema: "transaction",
                table: "Orders",
                columns: new[] { "TenantId", "OrderReference" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_TenantId_Status",
                schema: "transaction",
                table: "Orders",
                columns: new[] { "TenantId", "Status" });

            migrationBuilder.AddForeignKey(
                name: "FK_Transactions_Orders_OrderId",
                schema: "transaction",
                table: "Transactions",
                column: "OrderId",
                principalSchema: "transaction",
                principalTable: "Orders",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Transactions_Orders_OrderId",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropTable(
                name: "Orders",
                schema: "transaction");

            migrationBuilder.DropIndex(
                name: "IX_Transactions_OrderId",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ChargeDetails",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "CommissionDetails",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "Currency",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ExternalFundId",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ExternalFundIdOtherType",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ExternalFundIdType",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "LegId",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "OrderId",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "PriceAmount",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "PriceCurrency",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "PriceType",
                schema: "transaction",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "TaxDetails",
                schema: "transaction",
                table: "Transactions");
        }
    }
}

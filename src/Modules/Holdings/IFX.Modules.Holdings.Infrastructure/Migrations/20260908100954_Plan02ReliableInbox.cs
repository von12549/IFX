using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Holdings.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Plan02ReliableInbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "InboxMessages",
                schema: "holdings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ConsumerId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    EventId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InboxMessages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "IntegrationEventQuarantine",
                schema: "holdings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    EventId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    EventType = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ReasonCode = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    QuarantinedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IntegrationEventQuarantine", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_InboxMessages_ConsumerId_EventId",
                schema: "holdings",
                table: "InboxMessages",
                columns: new[] { "ConsumerId", "EventId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IntegrationEventQuarantine_QuarantinedAt",
                schema: "holdings",
                table: "IntegrationEventQuarantine",
                column: "QuarantinedAt");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "InboxMessages",
                schema: "holdings");

            migrationBuilder.DropTable(
                name: "IntegrationEventQuarantine",
                schema: "holdings");
        }
    }
}

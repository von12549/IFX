using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Transaction.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Plan02ReliableOutbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "OutboxMessages",
                schema: "transaction",
                columns: table => new
                {
                    EventId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    EnvelopeVersion = table.Column<int>(type: "int", nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    SchemaVersion = table.Column<int>(type: "int", nullable: false),
                    OccurredAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    Producer = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Scope = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CorrelationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CausationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    TraceParent = table.Column<string>(type: "nvarchar(55)", maxLength: 55, nullable: true),
                    TraceState = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    Provenance = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Payload = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    PartitionKey = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Sequence = table.Column<long>(type: "bigint", nullable: false),
                    State = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    AttemptCount = table.Column<int>(type: "int", nullable: false),
                    NextAttemptAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    LeaseOwner = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    LeaseUntil = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    DeliveredAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    LastErrorCode = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    ConcurrencyToken = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OutboxMessages", x => x.EventId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_PartitionKey_Sequence",
                schema: "transaction",
                table: "OutboxMessages",
                columns: new[] { "PartitionKey", "Sequence" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_State_NextAttemptAt_LeaseUntil",
                schema: "transaction",
                table: "OutboxMessages",
                columns: new[] { "State", "NextAttemptAt", "LeaseUntil" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OutboxMessages",
                schema: "transaction");
        }
    }
}

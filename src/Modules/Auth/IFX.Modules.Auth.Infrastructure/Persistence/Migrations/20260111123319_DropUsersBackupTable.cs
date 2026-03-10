using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class DropUsersBackupTable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Drop the UsersBackup table after successful verification in Phase 2.11
            migrationBuilder.Sql("DROP TABLE IF EXISTS [auth].[UsersBackup];");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Note: Cannot restore UsersBackup table as data is no longer available
            // Rollback to previous migration (SplitUserTableIntoUserAndUserIdentity) if needed
        }
    }
}

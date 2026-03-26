using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedPlatformAdminUser : Migration
    {
        // Stable PlatformAdmin GlobalRole ID — matches SeedGlobalRoles migration
        private const string PlatformAdminId = "0195d1a0-0000-7000-8000-000000000001";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($"""
                INSERT INTO auth.UserGlobalRoles (UserId, GlobalRoleId, AssignedAt)
                SELECT u.Id, '{PlatformAdminId}', GETUTCDATE()
                FROM auth.Users u
                WHERE u.DisplayName = 'Xiaolong Feng'
                  AND NOT EXISTS (
                    SELECT 1 FROM auth.UserGlobalRoles x
                    WHERE x.UserId = u.Id AND x.GlobalRoleId = '{PlatformAdminId}'
                  );
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($"""
                DELETE ugr
                FROM auth.UserGlobalRoles ugr
                JOIN auth.Users u ON u.Id = ugr.UserId
                WHERE u.DisplayName = 'Xiaolong Feng'
                  AND ugr.GlobalRoleId = '{PlatformAdminId}';
                """);
        }
    }
}

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminUserSeed : Migration
    {
        // Seed GUIDs — stable across all deployments
        private const string UserId         = "8314F7DA-2F5D-4128-A705-957CE0C3972E";
        private const string UserIdentityId = "294B1D4A-6E22-4BE2-845B-F5852F9165C8";
        // IdpId = IFX Cognito — seeded in InitialCreate
        private const string IdpId          = "B1B2C3D4-0002-0000-0000-000000000001";
        private const string SeedDate       = "2026-03-20 17:54:07";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 1. Seed user
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Users] WHERE [Id] = '{UserId}')
                    INSERT INTO [auth].[Users] ([Id], [IsActive], [DisplayName], [CreatedAt], [UpdatedAt])
                    VALUES ('{UserId}', 1, 'Xiaolong Feng', '{SeedDate}', '{SeedDate}')
                """);

            // 2. Seed UserIdentity (linked to IFX Cognito IdP)
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[UserIdentities] WHERE [Id] = '{UserIdentityId}')
                    INSERT INTO [auth].[UserIdentities]
                        ([Id], [UserId], [IdpId], [Issuer], [Subject], [Email],
                         [FirstName], [LastName], [PhoneNumber], [BirthDate],
                         [EmailVerified], [PhoneNumberVerified], [LastSyncedAt], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{UserIdentityId}', '{UserId}', '{IdpId}',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         '59cee488-6091-7036-dd07-e2519702a444',
                         'von12549@gmail.com',
                         'Xiaolong', 'Feng', '', '',
                         1, 0, '{SeedDate}', '{SeedDate}', '{SeedDate}')
                """);

            // 3. Assign Admin role (looked up by name — role GUID varies per deployment)
            migrationBuilder.Sql($"""
                INSERT INTO [auth].[UserRoles] ([RolesId], [UserId])
                SELECT r.[Id], '{UserId}'
                FROM   [auth].[Roles] r
                WHERE  r.[Name] = 'Admin'
                  AND  NOT EXISTS (
                       SELECT 1 FROM [auth].[UserRoles] ur
                       WHERE ur.[RolesId] = r.[Id] AND ur.[UserId] = '{UserId}')
                """);

            // 4. Assign TestGroup (looked up by name — group GUID varies per deployment)
            migrationBuilder.Sql($"""
                INSERT INTO [auth].[UserRoleGroups] ([RoleGroupsId], [UserId])
                SELECT rg.[Id], '{UserId}'
                FROM   [auth].[RoleGroups] rg
                WHERE  rg.[Name] = 'TestGroup'
                  AND  NOT EXISTS (
                       SELECT 1 FROM [auth].[UserRoleGroups] urg
                       WHERE urg.[RoleGroupsId] = rg.[Id] AND urg.[UserId] = '{UserId}')
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($"DELETE FROM [auth].[UserRoleGroups] WHERE [UserId] = '{UserId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserRoles]      WHERE [UserId] = '{UserId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserIdentities] WHERE [Id]     = '{UserIdentityId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[Users]          WHERE [Id]     = '{UserId}'");
        }
    }
}

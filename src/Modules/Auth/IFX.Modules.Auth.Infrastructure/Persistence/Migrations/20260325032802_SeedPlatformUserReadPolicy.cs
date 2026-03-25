using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedPlatformUserReadPolicy : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Seed the platform-level "Read Own Profile" policy (TenantId = NULL).
            // Applies to all tenants that have no tenant-specific override for user/read.
            // Idempotent: skipped if the row already exists.
            migrationBuilder.Sql(@"
DECLARE @UserId   UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID()
DECLARE @Now      DATETIME2        = GETUTCDATE()

IF @UserId IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM auth.PolicyDefinitions
       WHERE TenantId IS NULL AND ResourceType = 'user' AND Action = 'read')
BEGIN
    INSERT INTO auth.PolicyDefinitions
        (Id, TenantId, Name, Description, ResourceType, Action,
         ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
    VALUES (
        @PolicyId, NULL,
        'Read Own Profile (Platform Default)',
        'Platform-wide default: allows any user to read their own profile within the same tenant.',
        'user', 'read',
        '[{""TemplateName"":""SameTenant"",""Parameters"":null},{""TemplateName"":""CreatedByMe"",""Parameters"":null}]',
        1, @UserId, @UserId, @Now, @Now)
END
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
DELETE FROM auth.PolicyDefinitions
WHERE TenantId IS NULL AND ResourceType = 'user' AND Action = 'read'
");
        }
    }
}

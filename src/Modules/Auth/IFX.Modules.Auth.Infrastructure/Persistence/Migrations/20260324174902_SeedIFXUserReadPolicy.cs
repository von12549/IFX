using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedIFXUserReadPolicy : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Seed the "Read Own Profile" policy for the IFX tenant.
            // Tenant ID and user ID are resolved at migration-run time via subqueries.
            // The IF guard makes the insert idempotent — safe to run multiple times.
            // If the IFX tenant or Xiaolong Feng's user row does not yet exist (e.g. a
            // fresh CI environment), the insert is silently skipped; the static fallback
            // in StaticAbacPolicyResolver keeps the system functional.
            migrationBuilder.Sql(@"
DECLARE @TenantId  UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Tenants WHERE Name = 'IFX')
DECLARE @UserId    UNIQUEIDENTIFIER = (
    SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
DECLARE @PolicyId  UNIQUEIDENTIFIER = NEWID()
DECLARE @Now       DATETIME2        = GETUTCDATE()

IF @TenantId IS NOT NULL AND @UserId IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM auth.PolicyDefinitions
       WHERE TenantId = @TenantId AND ResourceType = 'user' AND Action = 'read')
BEGIN
    INSERT INTO auth.PolicyDefinitions
        (Id, TenantId, Name, Description, ResourceType, Action,
         ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
    VALUES (
        @PolicyId, @TenantId,
        'Read Own Profile',
        'Allows a user to read their own profile within the same tenant.',
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
WHERE ResourceType = 'user' AND Action = 'read'
  AND TenantId = (SELECT TOP 1 Id FROM auth.Tenants WHERE Name = 'IFX')
");
        }
    }
}

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ReplacePermissionsWithExpandedActions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Step 1: Insert 45 new permissions (idempotent)
            migrationBuilder.Sql("""
                DECLARE @now DATETIME2 = GETUTCDATE();
                INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], @now, @now
                FROM (VALUES
                    (NEWID(), 'User:list',              'List users within tenant'),
                    (NEWID(), 'User:read',              'View a specific user'),
                    (NEWID(), 'User:create',            'Create a user'),
                    (NEWID(), 'User:update',            'Update user / assign roles, departments, tenants'),
                    (NEWID(), 'User:delete',            'Deactivate or delete a user'),
                    (NEWID(), 'Role:list',              'List roles'),
                    (NEWID(), 'Role:read',              'View a specific role'),
                    (NEWID(), 'Role:create',            'Create a role'),
                    (NEWID(), 'Role:update',            'Update a role or assign permissions'),
                    (NEWID(), 'Role:delete',            'Delete a role'),
                    (NEWID(), 'RoleGroup:list',         'List role groups'),
                    (NEWID(), 'RoleGroup:read',         'View a specific role group'),
                    (NEWID(), 'RoleGroup:create',       'Create a role group'),
                    (NEWID(), 'RoleGroup:update',       'Update a role group or assign roles'),
                    (NEWID(), 'RoleGroup:delete',       'Delete a role group'),
                    (NEWID(), 'Permission:list',        'List permissions'),
                    (NEWID(), 'Permission:read',        'View a specific permission'),
                    (NEWID(), 'Permission:create',      'Create a permission'),
                    (NEWID(), 'Permission:update',      'Update a permission'),
                    (NEWID(), 'Permission:delete',      'Delete a permission'),
                    (NEWID(), 'Idp:list',               'List identity providers'),
                    (NEWID(), 'Idp:read',               'View a specific identity provider'),
                    (NEWID(), 'Idp:create',             'Create an identity provider'),
                    (NEWID(), 'Idp:update',             'Update an identity provider'),
                    (NEWID(), 'Idp:delete',             'Delete an identity provider'),
                    (NEWID(), 'Department:list',        'List departments'),
                    (NEWID(), 'Department:read',        'View a specific department'),
                    (NEWID(), 'Department:create',      'Create a department'),
                    (NEWID(), 'Department:update',      'Update a department'),
                    (NEWID(), 'Department:delete',      'Delete a department'),
                    (NEWID(), 'Tenant:list',            'List all tenants'),
                    (NEWID(), 'Tenant:read',            'View a specific tenant'),
                    (NEWID(), 'Tenant:create',          'Create a tenant'),
                    (NEWID(), 'Tenant:update',          'Update a tenant'),
                    (NEWID(), 'Tenant:delete',          'Delete a tenant'),
                    (NEWID(), 'Policy:list',            'List tenant ABAC policies and available templates'),
                    (NEWID(), 'Policy:read',            'View a specific tenant ABAC policy'),
                    (NEWID(), 'Policy:create',          'Create a tenant ABAC policy'),
                    (NEWID(), 'Policy:update',          'Update a tenant ABAC policy'),
                    (NEWID(), 'Policy:delete',          'Delete a tenant ABAC policy'),
                    (NEWID(), 'Platform.Policy:list',   'List platform-level ABAC policies'),
                    (NEWID(), 'Platform.Policy:read',   'View a specific platform-level ABAC policy'),
                    (NEWID(), 'Platform.Policy:create', 'Create a platform-level ABAC policy'),
                    (NEWID(), 'Platform.Policy:update', 'Update a platform-level ABAC policy'),
                    (NEWID(), 'Platform.Policy:delete', 'Delete a platform-level ABAC policy')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])
                """);

            // Step 2: Delete old RolePermissions for the 18 old permissions
            migrationBuilder.Sql("""
                DELETE FROM [auth].[RolePermissions]
                WHERE [PermissionsId] IN (
                    SELECT [Id] FROM [auth].[Permissions]
                    WHERE [Name] IN (
                        'User.Read', 'User.Write',
                        'Role.Read', 'Role.Write',
                        'RoleGroup.Read', 'RoleGroup.Write',
                        'Permission.Read', 'Permission.Write',
                        'Idp.Read', 'Idp.Write',
                        'Tenant.Read', 'Tenant.Write',
                        'Department.Read', 'Department.Write',
                        'Policy.Read', 'Policy.Write',
                        'Platform.Policy.Read', 'Platform.Policy.Write'
                    )
                )
                """);

            // Step 3: Seed new RolePermissions
            // Admin gets all 45 new permissions
            migrationBuilder.Sql("""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] = 'Admin'
                  AND  p.[Name] IN (
                    'User:list', 'User:read', 'User:create', 'User:update', 'User:delete',
                    'Role:list', 'Role:read', 'Role:create', 'Role:update', 'Role:delete',
                    'RoleGroup:list', 'RoleGroup:read', 'RoleGroup:create', 'RoleGroup:update', 'RoleGroup:delete',
                    'Permission:list', 'Permission:read', 'Permission:create', 'Permission:update', 'Permission:delete',
                    'Idp:list', 'Idp:read', 'Idp:create', 'Idp:update', 'Idp:delete',
                    'Department:list', 'Department:read', 'Department:create', 'Department:update', 'Department:delete',
                    'Tenant:list', 'Tenant:read', 'Tenant:create', 'Tenant:update', 'Tenant:delete',
                    'Policy:list', 'Policy:read', 'Policy:create', 'Policy:update', 'Policy:delete',
                    'Platform.Policy:list', 'Platform.Policy:read', 'Platform.Policy:create', 'Platform.Policy:update', 'Platform.Policy:delete'
                  )
                  AND NOT EXISTS (
                    SELECT 1 FROM [auth].[RolePermissions] rp
                    WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);

            // User, SsoUser, PendingUser each get User:read only
            migrationBuilder.Sql("""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] IN ('User', 'SsoUser', 'PendingUser')
                  AND  p.[Name] = 'User:read'
                  AND NOT EXISTS (
                    SELECT 1 FROM [auth].[RolePermissions] rp
                    WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);

            // Step 4: Delete old 18 permissions (RolePermissions already cleaned in step 2)
            migrationBuilder.Sql("""
                DELETE FROM [auth].[Permissions]
                WHERE [Name] IN (
                    'User.Read', 'User.Write',
                    'Role.Read', 'Role.Write',
                    'RoleGroup.Read', 'RoleGroup.Write',
                    'Permission.Read', 'Permission.Write',
                    'Idp.Read', 'Idp.Write',
                    'Tenant.Read', 'Tenant.Write',
                    'Department.Read', 'Department.Write',
                    'Policy.Read', 'Policy.Write',
                    'Platform.Policy.Read', 'Platform.Policy.Write'
                )
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Step 1: Delete new RolePermissions
            migrationBuilder.Sql("""
                DELETE FROM [auth].[RolePermissions]
                WHERE [PermissionsId] IN (
                    SELECT [Id] FROM [auth].[Permissions]
                    WHERE [Name] IN (
                        'User:list', 'User:read', 'User:create', 'User:update', 'User:delete',
                        'Role:list', 'Role:read', 'Role:create', 'Role:update', 'Role:delete',
                        'RoleGroup:list', 'RoleGroup:read', 'RoleGroup:create', 'RoleGroup:update', 'RoleGroup:delete',
                        'Permission:list', 'Permission:read', 'Permission:create', 'Permission:update', 'Permission:delete',
                        'Idp:list', 'Idp:read', 'Idp:create', 'Idp:update', 'Idp:delete',
                        'Department:list', 'Department:read', 'Department:create', 'Department:update', 'Department:delete',
                        'Tenant:list', 'Tenant:read', 'Tenant:create', 'Tenant:update', 'Tenant:delete',
                        'Policy:list', 'Policy:read', 'Policy:create', 'Policy:update', 'Policy:delete',
                        'Platform.Policy:list', 'Platform.Policy:read', 'Platform.Policy:create', 'Platform.Policy:update', 'Platform.Policy:delete'
                    )
                )
                """);

            // Step 2: Delete new 45 permissions
            migrationBuilder.Sql("""
                DELETE FROM [auth].[Permissions]
                WHERE [Name] IN (
                    'User:list', 'User:read', 'User:create', 'User:update', 'User:delete',
                    'Role:list', 'Role:read', 'Role:create', 'Role:update', 'Role:delete',
                    'RoleGroup:list', 'RoleGroup:read', 'RoleGroup:create', 'RoleGroup:update', 'RoleGroup:delete',
                    'Permission:list', 'Permission:read', 'Permission:create', 'Permission:update', 'Permission:delete',
                    'Idp:list', 'Idp:read', 'Idp:create', 'Idp:update', 'Idp:delete',
                    'Department:list', 'Department:read', 'Department:create', 'Department:update', 'Department:delete',
                    'Tenant:list', 'Tenant:read', 'Tenant:create', 'Tenant:update', 'Tenant:delete',
                    'Policy:list', 'Policy:read', 'Policy:create', 'Policy:update', 'Policy:delete',
                    'Platform.Policy:list', 'Platform.Policy:read', 'Platform.Policy:create', 'Platform.Policy:update', 'Platform.Policy:delete'
                )
                """);

            // Step 3: Re-insert old 18 permissions
            migrationBuilder.Sql("""
                DECLARE @now DATETIME2 = GETUTCDATE();
                INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], @now, @now
                FROM (VALUES
                    (NEWID(), 'User.Read',              'View user data'),
                    (NEWID(), 'User.Write',             'Create/update user data'),
                    (NEWID(), 'Role.Read',              'View roles'),
                    (NEWID(), 'Role.Write',             'Create/update roles'),
                    (NEWID(), 'RoleGroup.Read',         'View role groups'),
                    (NEWID(), 'RoleGroup.Write',        'Create/update role groups'),
                    (NEWID(), 'Permission.Read',        'View permissions'),
                    (NEWID(), 'Permission.Write',       'Create/update permissions'),
                    (NEWID(), 'Idp.Read',               'View identity providers'),
                    (NEWID(), 'Idp.Write',              'Create/update identity providers'),
                    (NEWID(), 'Tenant.Read',            'View tenants'),
                    (NEWID(), 'Tenant.Write',           'Create/update/delete tenants'),
                    (NEWID(), 'Department.Read',        'View departments'),
                    (NEWID(), 'Department.Write',       'Create/update/delete departments'),
                    (NEWID(), 'Policy.Read',            'View ABAC policy definitions'),
                    (NEWID(), 'Policy.Write',           'Create/update/delete ABAC policy definitions'),
                    (NEWID(), 'Platform.Policy.Read',   'View platform-level ABAC policy definitions'),
                    (NEWID(), 'Platform.Policy.Write',  'Create/update/delete platform-level ABAC policy definitions')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])
                """);

            // Step 4: Re-seed old RolePermissions
            // Admin gets all 18
            migrationBuilder.Sql("""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] = 'Admin'
                  AND  p.[Name] IN (
                    'User.Read', 'User.Write',
                    'Role.Read', 'Role.Write',
                    'RoleGroup.Read', 'RoleGroup.Write',
                    'Permission.Read', 'Permission.Write',
                    'Idp.Read', 'Idp.Write',
                    'Tenant.Read', 'Tenant.Write',
                    'Department.Read', 'Department.Write',
                    'Policy.Read', 'Policy.Write',
                    'Platform.Policy.Read', 'Platform.Policy.Write'
                  )
                  AND NOT EXISTS (
                    SELECT 1 FROM [auth].[RolePermissions] rp
                    WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);

            // User: User.Read + User.Write
            migrationBuilder.Sql("""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] = 'User'
                  AND  p.[Name] IN ('User.Read', 'User.Write')
                  AND NOT EXISTS (
                    SELECT 1 FROM [auth].[RolePermissions] rp
                    WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);

            // SsoUser + PendingUser: User.Read only
            migrationBuilder.Sql("""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT r.[Id], p.[Id]
                FROM   [auth].[Roles] r
                       CROSS JOIN [auth].[Permissions] p
                WHERE  r.[Name] IN ('SsoUser', 'PendingUser')
                  AND  p.[Name] = 'User.Read'
                  AND NOT EXISTS (
                    SELECT 1 FROM [auth].[RolePermissions] rp
                    WHERE rp.[RoleId] = r.[Id] AND rp.[PermissionsId] = p.[Id])
                """);
        }
    }
}

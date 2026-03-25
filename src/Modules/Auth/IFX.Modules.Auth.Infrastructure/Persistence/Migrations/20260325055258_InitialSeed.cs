using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialSeed : Migration
    {
        // ── Stable GUIDs ──────────────────────────────────────────────────────────
        private const string IFXTenantId          = "AAAAAAAA-0001-0000-0000-000000000001";
        private const string TestDeptId           = "AAAAAAAA-0002-0000-0000-000000000001";
        private const string IdpIfxCognitoId      = "B1B2C3D4-0002-0000-0000-000000000001";
        private const string IdpTestExternalId    = "B1B2C3D4-0002-0000-0000-000000000002";
        private const string IdpVonCognitoId      = "B1B2C3D4-0002-0000-0000-000000000003";
        private const string RoleAdminId          = "D0000000-0001-0000-0000-000000000001";
        private const string RoleUserId           = "D0000000-0001-0000-0000-000000000002";
        private const string RoleSsoUserId        = "D0000000-0001-0000-0000-000000000003";
        private const string RolePendingId        = "D0000000-0001-0000-0000-000000000004";
        private const string RoleGroupTestId      = "D0000000-0002-0000-0000-000000000001";
        private const string PermUserList         = "E0000000-0000-0000-0000-000000000001";
        private const string PermUserRead         = "E0000000-0000-0000-0000-000000000002";
        private const string PermUserCreate       = "E0000000-0000-0000-0000-000000000003";
        private const string PermUserUpdate       = "E0000000-0000-0000-0000-000000000004";
        private const string PermUserDelete       = "E0000000-0000-0000-0000-000000000005";
        private const string PermRoleList         = "E0000000-0000-0000-0000-000000000006";
        private const string PermRoleRead         = "E0000000-0000-0000-0000-000000000007";
        private const string PermRoleCreate       = "E0000000-0000-0000-0000-000000000008";
        private const string PermRoleUpdate       = "E0000000-0000-0000-0000-000000000009";
        private const string PermRoleDelete       = "E0000000-0000-0000-0000-000000000010";
        private const string PermRoleGroupList    = "E0000000-0000-0000-0000-000000000011";
        private const string PermRoleGroupRead    = "E0000000-0000-0000-0000-000000000012";
        private const string PermRoleGroupCreate  = "E0000000-0000-0000-0000-000000000013";
        private const string PermRoleGroupUpdate  = "E0000000-0000-0000-0000-000000000014";
        private const string PermRoleGroupDelete  = "E0000000-0000-0000-0000-000000000015";
        private const string PermPermissionList   = "E0000000-0000-0000-0000-000000000016";
        private const string PermPermissionRead   = "E0000000-0000-0000-0000-000000000017";
        private const string PermPermissionCreate = "E0000000-0000-0000-0000-000000000018";
        private const string PermPermissionUpdate = "E0000000-0000-0000-0000-000000000019";
        private const string PermPermissionDelete = "E0000000-0000-0000-0000-000000000020";
        private const string PermIdpList          = "E0000000-0000-0000-0000-000000000021";
        private const string PermIdpRead          = "E0000000-0000-0000-0000-000000000022";
        private const string PermIdpCreate        = "E0000000-0000-0000-0000-000000000023";
        private const string PermIdpUpdate        = "E0000000-0000-0000-0000-000000000024";
        private const string PermIdpDelete        = "E0000000-0000-0000-0000-000000000025";
        private const string PermDepartmentList   = "E0000000-0000-0000-0000-000000000026";
        private const string PermDepartmentRead   = "E0000000-0000-0000-0000-000000000027";
        private const string PermDepartmentCreate = "E0000000-0000-0000-0000-000000000028";
        private const string PermDepartmentUpdate = "E0000000-0000-0000-0000-000000000029";
        private const string PermDepartmentDelete = "E0000000-0000-0000-0000-000000000030";
        private const string PermTenantList       = "E0000000-0000-0000-0000-000000000031";
        private const string PermTenantRead       = "E0000000-0000-0000-0000-000000000032";
        private const string PermTenantCreate     = "E0000000-0000-0000-0000-000000000033";
        private const string PermTenantUpdate     = "E0000000-0000-0000-0000-000000000034";
        private const string PermTenantDelete     = "E0000000-0000-0000-0000-000000000035";
        private const string PermPolicyList       = "E0000000-0000-0000-0000-000000000036";
        private const string PermPolicyRead       = "E0000000-0000-0000-0000-000000000037";
        private const string PermPolicyCreate     = "E0000000-0000-0000-0000-000000000038";
        private const string PermPolicyUpdate     = "E0000000-0000-0000-0000-000000000039";
        private const string PermPolicyDelete     = "E0000000-0000-0000-0000-000000000040";
        private const string PermPlatformPolicyList   = "E0000000-0000-0000-0000-000000000041";
        private const string PermPlatformPolicyRead   = "E0000000-0000-0000-0000-000000000042";
        private const string PermPlatformPolicyCreate = "E0000000-0000-0000-0000-000000000043";
        private const string PermPlatformPolicyUpdate = "E0000000-0000-0000-0000-000000000044";
        private const string PermPlatformPolicyDelete = "E0000000-0000-0000-0000-000000000045";
        private const string AdminUserId         = "8314F7DA-2F5D-4128-A705-957CE0C3972E";
        private const string AdminUserIdentityId = "294B1D4A-6E22-4BE2-845B-F5852F9165C8";
        private const string SeedDate            = "2026-01-01 00:00:00";
        // Used in SQL to avoid {{}} escaping issues in raw string literals
        private const string EmptyJson           = "{}";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 1. Tenant
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Tenants] WHERE [Id] = '{IFXTenantId}')
                    INSERT INTO [auth].[Tenants] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                    VALUES ('{IFXTenantId}', 'IFX', 'Default IFX tenant', '{SeedDate}', '{SeedDate}')
                """);

            // 2. Department
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Departments] WHERE [Id] = '{TestDeptId}')
                    INSERT INTO [auth].[Departments] ([Id], [Name], [Description], [TenantId], [CreatedAt], [UpdatedAt])
                    VALUES ('{TestDeptId}', 'Test', 'Test department', '{IFXTenantId}', '{SeedDate}', '{SeedDate}')
                """);

            // 3. Idps (TenantId = IFX)
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Idps] WHERE [Id] = '{IdpIfxCognitoId}')
                    INSERT INTO [auth].[Idps]
                        ([Id], [Name], [Issuer], [Authority], [Description], [LoginUrl],
                         [IdpType], [IsPrimary], [Enabled], [AutoProvisionEnabled],
                         [TenantId], [ExpectedAudiences], [AllowedAlgs], [RequiredScopes],
                         [ClaimMapping], [ClockSkewSeconds], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{IdpIfxCognitoId}',
                         'IFX Cognito',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         'IFX AWS Cognito Identity Provider',
                         '', 'Internal', 1, 1, 1,
                         '{IFXTenantId}', '[]', '[]', '[]', '{EmptyJson}', 300,
                         '{SeedDate}', '{SeedDate}')

                IF NOT EXISTS (SELECT 1 FROM [auth].[Idps] WHERE [Id] = '{IdpTestExternalId}')
                    INSERT INTO [auth].[Idps]
                        ([Id], [Name], [Issuer], [Authority], [Description], [LoginUrl],
                         [IdpType], [IsPrimary], [Enabled], [AutoProvisionEnabled],
                         [TenantId], [ExpectedAudiences], [AllowedAlgs], [RequiredScopes],
                         [ClaimMapping], [ClockSkewSeconds], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{IdpTestExternalId}',
                         'Test External Idp',
                         'https://test-external-idp.example.com',
                         'https://test-external-idp.example.com',
                         'External Identity Provider',
                         'https://test-external-idp.example.com/login',
                         'External', 0, 0, 0,
                         '{IFXTenantId}', '[]', '[]', '[]', '{EmptyJson}', 300,
                         '{SeedDate}', '{SeedDate}')

                IF NOT EXISTS (SELECT 1 FROM [auth].[Idps] WHERE [Id] = '{IdpVonCognitoId}')
                    INSERT INTO [auth].[Idps]
                        ([Id], [Name], [Issuer], [Authority], [Description], [LoginUrl],
                         [IdpType], [IsPrimary], [Enabled], [AutoProvisionEnabled],
                         [TenantId], [ExpectedAudiences], [AllowedAlgs], [RequiredScopes],
                         [ClaimMapping], [ClockSkewSeconds], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{IdpVonCognitoId}',
                         'VON Cognito Idp',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P',
                         'VON''s Private Cognito Identity Provider',
                         '', 'External', 0, 1, 1,
                         '{IFXTenantId}', '[]', '[]', '[]', '{EmptyJson}', 300,
                         '{SeedDate}', '{SeedDate}')
                """);

            // 4. Permissions (45 — idempotent via NOT EXISTS on Name)
            migrationBuilder.Sql($"""
                DECLARE @now DATETIME2 = '{SeedDate}';
                INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], @now, @now
                FROM (VALUES
                    ('{PermUserList}',           'User:list',             'List users within tenant'),
                    ('{PermUserRead}',           'User:read',             'Read a user''s details'),
                    ('{PermUserCreate}',         'User:create',           'Create a new user'),
                    ('{PermUserUpdate}',         'User:update',           'Update a user''s details'),
                    ('{PermUserDelete}',         'User:delete',           'Delete a user'),
                    ('{PermRoleList}',           'Role:list',             'List roles'),
                    ('{PermRoleRead}',           'Role:read',             'Read a role''s details'),
                    ('{PermRoleCreate}',         'Role:create',           'Create a new role'),
                    ('{PermRoleUpdate}',         'Role:update',           'Update a role'),
                    ('{PermRoleDelete}',         'Role:delete',           'Delete a role'),
                    ('{PermRoleGroupList}',      'RoleGroup:list',        'List role groups'),
                    ('{PermRoleGroupRead}',      'RoleGroup:read',        'Read a role group''s details'),
                    ('{PermRoleGroupCreate}',    'RoleGroup:create',      'Create a new role group'),
                    ('{PermRoleGroupUpdate}',    'RoleGroup:update',      'Update a role group'),
                    ('{PermRoleGroupDelete}',    'RoleGroup:delete',      'Delete a role group'),
                    ('{PermPermissionList}',     'Permission:list',       'List permissions'),
                    ('{PermPermissionRead}',     'Permission:read',       'Read a permission''s details'),
                    ('{PermPermissionCreate}',   'Permission:create',     'Create a new permission'),
                    ('{PermPermissionUpdate}',   'Permission:update',     'Update a permission'),
                    ('{PermPermissionDelete}',   'Permission:delete',     'Delete a permission'),
                    ('{PermIdpList}',            'Idp:list',              'List identity providers'),
                    ('{PermIdpRead}',            'Idp:read',              'Read an identity provider''s details'),
                    ('{PermIdpCreate}',          'Idp:create',            'Create a new identity provider'),
                    ('{PermIdpUpdate}',          'Idp:update',            'Update an identity provider'),
                    ('{PermIdpDelete}',          'Idp:delete',            'Delete an identity provider'),
                    ('{PermDepartmentList}',     'Department:list',       'List departments'),
                    ('{PermDepartmentRead}',     'Department:read',       'Read a department''s details'),
                    ('{PermDepartmentCreate}',   'Department:create',     'Create a new department'),
                    ('{PermDepartmentUpdate}',   'Department:update',     'Update a department'),
                    ('{PermDepartmentDelete}',   'Department:delete',     'Delete a department'),
                    ('{PermTenantList}',         'Tenant:list',           'List tenants'),
                    ('{PermTenantRead}',         'Tenant:read',           'Read a tenant''s details'),
                    ('{PermTenantCreate}',       'Tenant:create',         'Create a new tenant'),
                    ('{PermTenantUpdate}',       'Tenant:update',         'Update a tenant'),
                    ('{PermTenantDelete}',       'Tenant:delete',         'Delete a tenant'),
                    ('{PermPolicyList}',         'Policy:list',           'List ABAC policies'),
                    ('{PermPolicyRead}',         'Policy:read',           'Read an ABAC policy''s details'),
                    ('{PermPolicyCreate}',       'Policy:create',         'Create a new ABAC policy'),
                    ('{PermPolicyUpdate}',       'Policy:update',         'Update an ABAC policy'),
                    ('{PermPolicyDelete}',       'Policy:delete',         'Delete an ABAC policy'),
                    ('{PermPlatformPolicyList}',   'Platform.Policy:list',   'List platform-level ABAC policies'),
                    ('{PermPlatformPolicyRead}',   'Platform.Policy:read',   'Read a platform-level ABAC policy'),
                    ('{PermPlatformPolicyCreate}', 'Platform.Policy:create', 'Create a platform-level ABAC policy'),
                    ('{PermPlatformPolicyUpdate}', 'Platform.Policy:update', 'Update a platform-level ABAC policy'),
                    ('{PermPlatformPolicyDelete}', 'Platform.Policy:delete', 'Delete a platform-level ABAC policy')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])
                """);

            // 5. Roles (TenantId = IFX)
            migrationBuilder.Sql($"""
                DECLARE @now DATETIME2 = '{SeedDate}';
                INSERT INTO [auth].[Roles] ([Id], [Name], [Description], [TenantId], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], '{IFXTenantId}', @now, @now
                FROM (VALUES
                    ('{RoleAdminId}',   'Admin',      'Administrator with full access'),
                    ('{RoleUserId}',    'User',        'Standard user with limited permissions'),
                    ('{RoleSsoUserId}', 'SsoUser',     'SSO authenticated user'),
                    ('{RolePendingId}', 'PendingUser', 'Pending user awaiting approval')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Roles] r WHERE r.[Id] = v.[Id])
                """);

            // 6. RoleGroup
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[RoleGroups] WHERE [Id] = '{RoleGroupTestId}')
                    INSERT INTO [auth].[RoleGroups] ([Id], [Name], [Description], [TenantId], [CreatedAt], [UpdatedAt])
                    VALUES ('{RoleGroupTestId}', 'TestGroup', 'Test role group', '{IFXTenantId}', '{SeedDate}', '{SeedDate}')
                """);

            // 7. RoleGroupRoles: TestGroup -> Admin, User, SsoUser
            migrationBuilder.Sql($"""
                INSERT INTO [auth].[RoleGroupRoles] ([RoleGroupId], [RolesId])
                SELECT v.[RoleGroupId], v.[RolesId]
                FROM (VALUES
                    ('{RoleGroupTestId}', '{RoleAdminId}'),
                    ('{RoleGroupTestId}', '{RoleUserId}'),
                    ('{RoleGroupTestId}', '{RoleSsoUserId}')
                ) AS v([RoleGroupId], [RolesId])
                WHERE NOT EXISTS (
                    SELECT 1 FROM [auth].[RoleGroupRoles] x
                    WHERE x.[RoleGroupId] = v.[RoleGroupId] AND x.[RolesId] = v.[RolesId])
                """);

            // 8. RolePermissions
            // Admin: all 45; User/SsoUser/PendingUser: User:read only
            migrationBuilder.Sql($"""
                INSERT INTO [auth].[RolePermissions] ([RoleId], [PermissionsId])
                SELECT v.[RoleId], v.[PermId]
                FROM (VALUES
                    ('{RoleAdminId}', '{PermUserList}'),
                    ('{RoleAdminId}', '{PermUserRead}'),
                    ('{RoleAdminId}', '{PermUserCreate}'),
                    ('{RoleAdminId}', '{PermUserUpdate}'),
                    ('{RoleAdminId}', '{PermUserDelete}'),
                    ('{RoleAdminId}', '{PermRoleList}'),
                    ('{RoleAdminId}', '{PermRoleRead}'),
                    ('{RoleAdminId}', '{PermRoleCreate}'),
                    ('{RoleAdminId}', '{PermRoleUpdate}'),
                    ('{RoleAdminId}', '{PermRoleDelete}'),
                    ('{RoleAdminId}', '{PermRoleGroupList}'),
                    ('{RoleAdminId}', '{PermRoleGroupRead}'),
                    ('{RoleAdminId}', '{PermRoleGroupCreate}'),
                    ('{RoleAdminId}', '{PermRoleGroupUpdate}'),
                    ('{RoleAdminId}', '{PermRoleGroupDelete}'),
                    ('{RoleAdminId}', '{PermPermissionList}'),
                    ('{RoleAdminId}', '{PermPermissionRead}'),
                    ('{RoleAdminId}', '{PermPermissionCreate}'),
                    ('{RoleAdminId}', '{PermPermissionUpdate}'),
                    ('{RoleAdminId}', '{PermPermissionDelete}'),
                    ('{RoleAdminId}', '{PermIdpList}'),
                    ('{RoleAdminId}', '{PermIdpRead}'),
                    ('{RoleAdminId}', '{PermIdpCreate}'),
                    ('{RoleAdminId}', '{PermIdpUpdate}'),
                    ('{RoleAdminId}', '{PermIdpDelete}'),
                    ('{RoleAdminId}', '{PermDepartmentList}'),
                    ('{RoleAdminId}', '{PermDepartmentRead}'),
                    ('{RoleAdminId}', '{PermDepartmentCreate}'),
                    ('{RoleAdminId}', '{PermDepartmentUpdate}'),
                    ('{RoleAdminId}', '{PermDepartmentDelete}'),
                    ('{RoleAdminId}', '{PermTenantList}'),
                    ('{RoleAdminId}', '{PermTenantRead}'),
                    ('{RoleAdminId}', '{PermTenantCreate}'),
                    ('{RoleAdminId}', '{PermTenantUpdate}'),
                    ('{RoleAdminId}', '{PermTenantDelete}'),
                    ('{RoleAdminId}', '{PermPolicyList}'),
                    ('{RoleAdminId}', '{PermPolicyRead}'),
                    ('{RoleAdminId}', '{PermPolicyCreate}'),
                    ('{RoleAdminId}', '{PermPolicyUpdate}'),
                    ('{RoleAdminId}', '{PermPolicyDelete}'),
                    ('{RoleAdminId}', '{PermPlatformPolicyList}'),
                    ('{RoleAdminId}', '{PermPlatformPolicyRead}'),
                    ('{RoleAdminId}', '{PermPlatformPolicyCreate}'),
                    ('{RoleAdminId}', '{PermPlatformPolicyUpdate}'),
                    ('{RoleAdminId}', '{PermPlatformPolicyDelete}'),
                    ('{RoleUserId}',    '{PermUserRead}'),
                    ('{RoleSsoUserId}', '{PermUserRead}'),
                    ('{RolePendingId}', '{PermUserRead}')
                ) AS v([RoleId], [PermId])
                WHERE NOT EXISTS (
                    SELECT 1 FROM [auth].[RolePermissions] x
                    WHERE x.[RoleId] = v.[RoleId] AND x.[PermissionsId] = v.[PermId])
                """);

            // 9. Admin user
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Users] WHERE [Id] = '{AdminUserId}')
                    INSERT INTO [auth].[Users]
                        ([Id], [IsActive], [DisplayName], [PrimaryTenantId], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{AdminUserId}', 1, 'Xiaolong Feng', '{IFXTenantId}', '{SeedDate}', '{SeedDate}')
                """);

            // 10. Admin UserIdentity
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[UserIdentities] WHERE [Id] = '{AdminUserIdentityId}')
                    INSERT INTO [auth].[UserIdentities]
                        ([Id], [UserId], [IdpId], [Issuer], [Subject], [Email],
                         [FirstName], [LastName], [PhoneNumber], [BirthDate],
                         [EmailVerified], [PhoneNumberVerified], [LastSyncedAt], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{AdminUserIdentityId}', '{AdminUserId}', '{IdpIfxCognitoId}',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         '59cee488-6091-7036-dd07-e2519702a444',
                         'von12549@gmail.com',
                         'Xiaolong', 'Feng', '', '',
                         1, 0, '{SeedDate}', '{SeedDate}', '{SeedDate}')
                """);

            // 11. UserRoles: Admin user -> Admin role
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserRoles]
                    WHERE [RolesId] = '{RoleAdminId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserRoles] ([RolesId], [UserId])
                    VALUES ('{RoleAdminId}', '{AdminUserId}')
                """);

            // 12. UserRoleGroups: Admin user -> TestGroup
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserRoleGroups]
                    WHERE [RoleGroupsId] = '{RoleGroupTestId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserRoleGroups] ([RoleGroupsId], [UserId])
                    VALUES ('{RoleGroupTestId}', '{AdminUserId}')
                """);

            // 13. UserTenants: Admin user -> IFX tenant
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserTenants]
                    WHERE [TenantsId] = '{IFXTenantId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserTenants] ([TenantsId], [UserId])
                    VALUES ('{IFXTenantId}', '{AdminUserId}')
                """);

            // 14. UserDepartments: Admin user -> Test dept
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserDepartments]
                    WHERE [DepartmentsId] = '{TestDeptId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserDepartments] ([DepartmentsId], [UserId])
                    VALUES ('{TestDeptId}', '{AdminUserId}')
                """);

            // 15. PolicyDefinitions
            // IFX tenant: user/read "Read Own Profile"
            migrationBuilder.Sql(@"
DECLARE @TenantId  UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Tenants WHERE Name = 'IFX')
DECLARE @UserId    UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
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
END");

            // Platform-level: user/read "Read Own Profile (Platform Default)"
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
END");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Policies
            migrationBuilder.Sql("DELETE FROM [auth].[PolicyDefinitions] WHERE [ResourceType] = 'user' AND [Action] = 'read' AND [TenantId] IS NULL");
            migrationBuilder.Sql($"DELETE FROM [auth].[PolicyDefinitions] WHERE [ResourceType] = 'user' AND [Action] = 'read' AND [TenantId] = '{IFXTenantId}'");

            // User associations
            migrationBuilder.Sql($"DELETE FROM [auth].[UserDepartments] WHERE [UserId] = '{AdminUserId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserTenants]     WHERE [UserId] = '{AdminUserId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserRoleGroups]  WHERE [UserId] = '{AdminUserId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserRoles]       WHERE [UserId] = '{AdminUserId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[UserIdentities]  WHERE [Id] = '{AdminUserIdentityId}'");
            migrationBuilder.Sql($"DELETE FROM [auth].[Users]           WHERE [Id] = '{AdminUserId}'");

            // Role-permission assignments
            migrationBuilder.Sql($"DELETE FROM [auth].[RolePermissions] WHERE [RoleId] IN ('{RoleAdminId}', '{RoleUserId}', '{RoleSsoUserId}', '{RolePendingId}')");

            // Role group membership
            migrationBuilder.Sql($"DELETE FROM [auth].[RoleGroupRoles] WHERE [RoleGroupId] = '{RoleGroupTestId}'");

            // Idps
            migrationBuilder.Sql($"DELETE FROM [auth].[Idps] WHERE [Id] IN ('{IdpIfxCognitoId}', '{IdpTestExternalId}', '{IdpVonCognitoId}')");

            // RoleGroup
            migrationBuilder.Sql($"DELETE FROM [auth].[RoleGroups] WHERE [Id] = '{RoleGroupTestId}'");

            // Roles
            migrationBuilder.Sql($"DELETE FROM [auth].[Roles] WHERE [Id] IN ('{RoleAdminId}', '{RoleUserId}', '{RoleSsoUserId}', '{RolePendingId}')");

            // Permissions
            migrationBuilder.Sql($"""
                DELETE FROM [auth].[Permissions] WHERE [Id] IN (
                    '{PermUserList}', '{PermUserRead}', '{PermUserCreate}', '{PermUserUpdate}', '{PermUserDelete}',
                    '{PermRoleList}', '{PermRoleRead}', '{PermRoleCreate}', '{PermRoleUpdate}', '{PermRoleDelete}',
                    '{PermRoleGroupList}', '{PermRoleGroupRead}', '{PermRoleGroupCreate}', '{PermRoleGroupUpdate}', '{PermRoleGroupDelete}',
                    '{PermPermissionList}', '{PermPermissionRead}', '{PermPermissionCreate}', '{PermPermissionUpdate}', '{PermPermissionDelete}',
                    '{PermIdpList}', '{PermIdpRead}', '{PermIdpCreate}', '{PermIdpUpdate}', '{PermIdpDelete}',
                    '{PermDepartmentList}', '{PermDepartmentRead}', '{PermDepartmentCreate}', '{PermDepartmentUpdate}', '{PermDepartmentDelete}',
                    '{PermTenantList}', '{PermTenantRead}', '{PermTenantCreate}', '{PermTenantUpdate}', '{PermTenantDelete}',
                    '{PermPolicyList}', '{PermPolicyRead}', '{PermPolicyCreate}', '{PermPolicyUpdate}', '{PermPolicyDelete}',
                    '{PermPlatformPolicyList}', '{PermPlatformPolicyRead}', '{PermPlatformPolicyCreate}', '{PermPlatformPolicyUpdate}', '{PermPlatformPolicyDelete}'
                )
                """);

            // Department
            migrationBuilder.Sql($"DELETE FROM [auth].[Departments] WHERE [Id] = '{TestDeptId}'");

            // Tenant
            migrationBuilder.Sql($"DELETE FROM [auth].[Tenants] WHERE [Id] = '{IFXTenantId}'");
        }
    }
}

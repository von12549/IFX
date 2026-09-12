using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.IAM.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialSeed : Migration
    {
        // ── UUID v7 Stable Seed IDs ────────────────────────────────────────────────
        // Base timestamp: 2026-01-01T00:00:00.000Z (ms = 0x019B76DAA800)
        // Format: 019B76DA-A800-7{group:03X}-8000-{seq:012X}
        //
        // Group 001 — Tenants
        private const string IFXTenantId          = "019B76DA-A800-7001-8000-000000000001";
        // Group 002 — Departments
        private const string TestDeptId           = "019B76DA-A800-7002-8000-000000000001";
        // Group 003 — IdPs
        private const string IdpIfxCognitoId      = "019B76DA-A800-7003-8000-000000000001";
        private const string IdpTestExternalId    = "019B76DA-A800-7003-8000-000000000002";
        private const string IdpVonCognitoId      = "019B76DA-A800-7003-8000-000000000003";
        // Group 004 — Roles
        private const string RoleAdminId          = "019B76DA-A800-7004-8000-000000000001";
        private const string RoleUserId           = "019B76DA-A800-7004-8000-000000000002";
        private const string RoleSsoUserId        = "019B76DA-A800-7004-8000-000000000003";
        private const string RolePendingId        = "019B76DA-A800-7004-8000-000000000004";
        // Group 005 — RoleGroups
        private const string RoleGroupTestId      = "019B76DA-A800-7005-8000-000000000001";
        // Group 006 — Permissions (45)
        private const string PermUserList             = "019B76DA-A800-7006-8000-000000000001";
        private const string PermUserRead             = "019B76DA-A800-7006-8000-000000000002";
        private const string PermUserCreate           = "019B76DA-A800-7006-8000-000000000003";
        private const string PermUserUpdate           = "019B76DA-A800-7006-8000-000000000004";
        private const string PermUserDelete           = "019B76DA-A800-7006-8000-000000000005";
        private const string PermRoleList             = "019B76DA-A800-7006-8000-000000000006";
        private const string PermRoleRead             = "019B76DA-A800-7006-8000-000000000007";
        private const string PermRoleCreate           = "019B76DA-A800-7006-8000-000000000008";
        private const string PermRoleUpdate           = "019B76DA-A800-7006-8000-000000000009";
        private const string PermRoleDelete           = "019B76DA-A800-7006-8000-00000000000A";
        private const string PermRoleGroupList        = "019B76DA-A800-7006-8000-00000000000B";
        private const string PermRoleGroupRead        = "019B76DA-A800-7006-8000-00000000000C";
        private const string PermRoleGroupCreate      = "019B76DA-A800-7006-8000-00000000000D";
        private const string PermRoleGroupUpdate      = "019B76DA-A800-7006-8000-00000000000E";
        private const string PermRoleGroupDelete      = "019B76DA-A800-7006-8000-00000000000F";
        private const string PermPermissionList       = "019B76DA-A800-7006-8000-000000000010";
        private const string PermPermissionRead       = "019B76DA-A800-7006-8000-000000000011";
        private const string PermPermissionCreate     = "019B76DA-A800-7006-8000-000000000012";
        private const string PermPermissionUpdate     = "019B76DA-A800-7006-8000-000000000013";
        private const string PermPermissionDelete     = "019B76DA-A800-7006-8000-000000000014";
        private const string PermIdpList              = "019B76DA-A800-7006-8000-000000000015";
        private const string PermIdpRead              = "019B76DA-A800-7006-8000-000000000016";
        private const string PermIdpCreate            = "019B76DA-A800-7006-8000-000000000017";
        private const string PermIdpUpdate            = "019B76DA-A800-7006-8000-000000000018";
        private const string PermIdpDelete            = "019B76DA-A800-7006-8000-000000000019";
        private const string PermDepartmentList       = "019B76DA-A800-7006-8000-00000000001A";
        private const string PermDepartmentRead       = "019B76DA-A800-7006-8000-00000000001B";
        private const string PermDepartmentCreate     = "019B76DA-A800-7006-8000-00000000001C";
        private const string PermDepartmentUpdate     = "019B76DA-A800-7006-8000-00000000001D";
        private const string PermDepartmentDelete     = "019B76DA-A800-7006-8000-00000000001E";
        private const string PermTenantList           = "019B76DA-A800-7006-8000-00000000001F";
        private const string PermTenantRead           = "019B76DA-A800-7006-8000-000000000020";
        private const string PermTenantCreate         = "019B76DA-A800-7006-8000-000000000021";
        private const string PermTenantUpdate         = "019B76DA-A800-7006-8000-000000000022";
        private const string PermTenantDelete         = "019B76DA-A800-7006-8000-000000000023";
        private const string PermPolicyList           = "019B76DA-A800-7006-8000-000000000024";
        private const string PermPolicyRead           = "019B76DA-A800-7006-8000-000000000025";
        private const string PermPolicyCreate         = "019B76DA-A800-7006-8000-000000000026";
        private const string PermPolicyUpdate         = "019B76DA-A800-7006-8000-000000000027";
        private const string PermPolicyDelete         = "019B76DA-A800-7006-8000-000000000028";
        private const string PermPlatformPolicyList   = "019B76DA-A800-7006-8000-000000000029";
        private const string PermPlatformPolicyRead   = "019B76DA-A800-7006-8000-00000000002A";
        private const string PermPlatformPolicyCreate = "019B76DA-A800-7006-8000-00000000002B";
        private const string PermPlatformPolicyUpdate = "019B76DA-A800-7006-8000-00000000002C";
        private const string PermPlatformPolicyDelete = "019B76DA-A800-7006-8000-00000000002D";
        // Group 007 — Users
        private const string AdminUserId             = "019B76DA-A800-7007-8000-000000000001";
        // Group 008 — UserIdentities
        private const string AdminUserIdentityId     = "019B76DA-A800-7008-8000-000000000001";
        // Group 009 — Base PolicyDefinitions (stable IDs — no more NEWID())
        private const string PolicyUserReadIFX       = "019B76DA-A800-7009-8000-000000000001";
        private const string PolicyUserReadPlatform  = "019B76DA-A800-7009-8000-000000000002";
        // Group 00A — GlobalRoles
        private const string PlatformAdminId        = "019B76DA-A800-700A-8000-000000000001";
        private const string PlatformSupportId      = "019B76DA-A800-700A-8000-000000000002";
        private const string PlatformAuditorId      = "019B76DA-A800-700A-8000-000000000003";
        // Group 00B — PlatformSupport PolicyDefinitions
        private const string PSup_UserList           = "019B76DA-A800-700B-8000-000000000001";
        private const string PSup_UserRead           = "019B76DA-A800-700B-8000-000000000002";
        private const string PSup_RoleList           = "019B76DA-A800-700B-8000-000000000003";
        private const string PSup_RoleRead           = "019B76DA-A800-700B-8000-000000000004";
        private const string PSup_RoleGroupList      = "019B76DA-A800-700B-8000-000000000005";
        private const string PSup_RoleGroupRead      = "019B76DA-A800-700B-8000-000000000006";
        private const string PSup_DepartmentList     = "019B76DA-A800-700B-8000-000000000007";
        private const string PSup_DepartmentRead     = "019B76DA-A800-700B-8000-000000000008";
        private const string PSup_IdpList            = "019B76DA-A800-700B-8000-000000000009";
        private const string PSup_IdpRead            = "019B76DA-A800-700B-8000-00000000000A";
        private const string PSup_PolicyList         = "019B76DA-A800-700B-8000-00000000000B";
        private const string PSup_PolicyRead         = "019B76DA-A800-700B-8000-00000000000C";
        private const string PSup_PlatformPolicyList = "019B76DA-A800-700B-8000-00000000000D";
        private const string PSup_PlatformPolicyRead = "019B76DA-A800-700B-8000-00000000000E";
        // Group 00C — PlatformAuditor PolicyDefinitions
        private const string PAud_UserList           = "019B76DA-A800-700C-8000-000000000001";
        private const string PAud_RoleList           = "019B76DA-A800-700C-8000-000000000002";
        private const string PAud_RoleGroupList      = "019B76DA-A800-700C-8000-000000000003";
        private const string PAud_DepartmentList     = "019B76DA-A800-700C-8000-000000000004";
        private const string PAud_IdpList            = "019B76DA-A800-700C-8000-000000000005";
        private const string PAud_PolicyList         = "019B76DA-A800-700C-8000-000000000006";
        private const string PAud_PlatformPolicyList = "019B76DA-A800-700C-8000-000000000007";

        // Condition JSON fragments
        private const string ST   = @"[{""TemplateName"":""SameTenant"",""Parameters"":null}]";
        private const string STCM = @"[{""TemplateName"":""SameTenant"",""Parameters"":null},{""TemplateName"":""CreatedByMe"",""Parameters"":null}]";
        private const string GRI_SUPPORT = @"[{""TemplateName"":""GlobalRoleIncludes"",""Parameters"":{""global_role"":""PlatformSupport""}}]";
        private const string GRI_AUDITOR = @"[{""TemplateName"":""GlobalRoleIncludes"",""Parameters"":{""global_role"":""PlatformAuditor""}}]";

        // Stable SeedAbacPolicies IDs — kept exactly as originally generated with Uuid.NewSequential()
        private const string PolicyUserUpdate          = "019D2496-51A8-7142-9477-1B0BAC381708";
        private const string PolicyUserList            = "019D2496-51AE-71DC-81C8-6FE4E4B0238A";
        private const string PolicyUserReadAdmin       = "019D2496-51AE-71DD-B19F-EEA01E90EE7A";
        private const string PolicyUserManage          = "019D2496-51AE-71DE-BB1B-B892536392FE";
        private const string PolicyRoleList            = "019D2496-51AE-71DF-BF36-D64FB791ACC1";
        private const string PolicyRoleRead            = "019D2496-51AE-71E0-AC33-7569D04F5FE0";
        private const string PolicyRoleCreate          = "019D2496-51AE-71E1-96DC-1F5939EF403A";
        private const string PolicyRoleUpdate          = "019D2496-51AE-71E2-8986-E1D8661CD3FC";
        private const string PolicyRoleDelete          = "019D2496-51AE-71E3-9A89-C9C1B52C0D92";
        private const string PolicyRoleManage          = "019D2496-51AE-71E4-97C5-0DB3C00F275C";
        private const string PolicyRoleGroupList       = "019D2496-51AE-71E5-86FA-C585D4D34B2E";
        private const string PolicyRoleGroupRead       = "019D2496-51AE-71E6-AE4F-3206A5B23CC4";
        private const string PolicyRoleGroupCreate     = "019D2496-51AE-71E7-BD60-CCE40B2BFFCF";
        private const string PolicyRoleGroupUpdate     = "019D2496-51AE-71E8-8713-90E64AAB61A8";
        private const string PolicyRoleGroupDelete     = "019D2496-51AE-71E9-AE5F-1C14B3F890F7";
        private const string PolicyRoleGroupManage     = "019D2496-51AE-71EA-B67A-2402914A9726";
        private const string PolicyDepartmentList      = "019D2496-51AE-71EB-B8C5-626ADEAD3EC8";
        private const string PolicyDepartmentRead      = "019D2496-51AE-71EC-88D0-0B2EE32A2A0E";
        private const string PolicyDepartmentCreate    = "019D2496-51AE-71ED-8525-B11297B84B25";
        private const string PolicyDepartmentUpdate    = "019D2496-51AE-71EE-8F8F-2FC854997826";
        private const string PolicyDepartmentDelete    = "019D2496-51AE-71EF-AF35-0D8E8F6B3A90";
        private const string PolicyDepartmentManage    = "019D2496-51AE-71F0-9785-E8EE3962E485";
        private const string PolicyIdpList             = "019D2496-51AE-71F1-B650-13D31331F7D0";
        private const string PolicyIdpRead             = "019D2496-51AE-71F2-8A50-8FA4F3A66991";
        private const string PolicyIdpCreate           = "019D2496-51AE-71F3-A250-5A8E13EBB967";
        private const string PolicyIdpUpdate           = "019D2496-51AE-71F4-BC92-CDA87AE70914";
        private const string PolicyPolicyList          = "019D2496-51AE-71F5-9C34-5D58B3F18601";
        private const string PolicyPolicyRead          = "019D2496-51AE-71F6-8BC6-50B16F3BBB5E";
        private const string PolicyPolicyCreate        = "019D2496-51AE-71F7-B275-3258D58FA4AB";
        private const string PolicyPolicyUpdate        = "019D2496-51AE-71F8-A2C7-E13DD129CBBC";
        private const string PolicyPolicyDelete        = "019D2496-51AE-71F9-BA47-19CD487EBC3A";

        private const string SeedDate = "2026-01-01 00:00:00";
        private const string EmptyJson = "{}";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ── 1. Tenant ──────────────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Tenants] WHERE [Id] = '{IFXTenantId}')
                    INSERT INTO [auth].[Tenants] ([Id], [Name], [Description], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES ('{IFXTenantId}', 'IFX', 'Default IFX tenant', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 2. Department ──────────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Departments] WHERE [Id] = '{TestDeptId}')
                    INSERT INTO [auth].[Departments] ([Id], [Name], [Description], [TenantId], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES ('{TestDeptId}', 'Test', 'Test department', '{IFXTenantId}', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 3. IdPs ────────────────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Idps] WHERE [Id] = '{IdpIfxCognitoId}')
                    INSERT INTO [auth].[Idps]
                        ([Id], [Name], [Issuer], [Authority], [Description], [LoginUrl],
                         [IdpType], [IsPrimary], [Enabled], [AutoProvisionEnabled],
                         [TenantId], [ExpectedAudiences], [AllowedAlgs], [RequiredScopes],
                         [ClaimMapping], [ClockSkewSeconds], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{IdpIfxCognitoId}',
                         'IFX Cognito',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         'IFX AWS Cognito Identity Provider',
                         '', 'Internal', 1, 1, 1,
                         '{IFXTenantId}', '[]', '[]', '[]', '{EmptyJson}', 300,
                         '{AdminUserId}', '{SeedDate}', '{SeedDate}')

                IF NOT EXISTS (SELECT 1 FROM [auth].[Idps] WHERE [Id] = '{IdpTestExternalId}')
                    INSERT INTO [auth].[Idps]
                        ([Id], [Name], [Issuer], [Authority], [Description], [LoginUrl],
                         [IdpType], [IsPrimary], [Enabled], [AutoProvisionEnabled],
                         [TenantId], [ExpectedAudiences], [AllowedAlgs], [RequiredScopes],
                         [ClaimMapping], [ClockSkewSeconds], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{IdpTestExternalId}',
                         'Test External Idp',
                         'https://test-external-idp.example.com',
                         'https://test-external-idp.example.com',
                         'External Identity Provider',
                         'https://test-external-idp.example.com/login',
                         'External', 0, 0, 0,
                         '{IFXTenantId}', '[]', '[]', '[]', '{EmptyJson}', 300,
                         '{AdminUserId}', '{SeedDate}', '{SeedDate}')

                IF NOT EXISTS (SELECT 1 FROM [auth].[Idps] WHERE [Id] = '{IdpVonCognitoId}')
                    INSERT INTO [auth].[Idps]
                        ([Id], [Name], [Issuer], [Authority], [Description], [LoginUrl],
                         [IdpType], [IsPrimary], [Enabled], [AutoProvisionEnabled],
                         [TenantId], [ExpectedAudiences], [AllowedAlgs], [RequiredScopes],
                         [ClaimMapping], [ClockSkewSeconds], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{IdpVonCognitoId}',
                         'VON Cognito Idp',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P',
                         'VON''s Private Cognito Identity Provider',
                         '', 'External', 0, 1, 1,
                         '{IFXTenantId}', '[]', '[]', '[]', '{EmptyJson}', 300,
                         '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 4. Permissions (45) ────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                DECLARE @now DATETIME2 = '{SeedDate}';
                INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], @now, @now
                FROM (VALUES
                    ('{PermUserList}',           'User:list',              'List users within tenant'),
                    ('{PermUserRead}',           'User:read',              'Read a user''s details'),
                    ('{PermUserCreate}',         'User:create',            'Create a new user'),
                    ('{PermUserUpdate}',         'User:update',            'Update a user''s details'),
                    ('{PermUserDelete}',         'User:delete',            'Delete a user'),
                    ('{PermRoleList}',           'Role:list',              'List roles'),
                    ('{PermRoleRead}',           'Role:read',              'Read a role''s details'),
                    ('{PermRoleCreate}',         'Role:create',            'Create a new role'),
                    ('{PermRoleUpdate}',         'Role:update',            'Update a role'),
                    ('{PermRoleDelete}',         'Role:delete',            'Delete a role'),
                    ('{PermRoleGroupList}',      'RoleGroup:list',         'List role groups'),
                    ('{PermRoleGroupRead}',      'RoleGroup:read',         'Read a role group''s details'),
                    ('{PermRoleGroupCreate}',    'RoleGroup:create',       'Create a new role group'),
                    ('{PermRoleGroupUpdate}',    'RoleGroup:update',       'Update a role group'),
                    ('{PermRoleGroupDelete}',    'RoleGroup:delete',       'Delete a role group'),
                    ('{PermPermissionList}',     'Permission:list',        'List permissions'),
                    ('{PermPermissionRead}',     'Permission:read',        'Read a permission''s details'),
                    ('{PermPermissionCreate}',   'Permission:create',      'Create a new permission'),
                    ('{PermPermissionUpdate}',   'Permission:update',      'Update a permission'),
                    ('{PermPermissionDelete}',   'Permission:delete',      'Delete a permission'),
                    ('{PermIdpList}',            'Idp:list',               'List identity providers'),
                    ('{PermIdpRead}',            'Idp:read',               'Read an identity provider''s details'),
                    ('{PermIdpCreate}',          'Idp:create',             'Create a new identity provider'),
                    ('{PermIdpUpdate}',          'Idp:update',             'Update an identity provider'),
                    ('{PermIdpDelete}',          'Idp:delete',             'Delete an identity provider'),
                    ('{PermDepartmentList}',     'Department:list',        'List departments'),
                    ('{PermDepartmentRead}',     'Department:read',        'Read a department''s details'),
                    ('{PermDepartmentCreate}',   'Department:create',      'Create a new department'),
                    ('{PermDepartmentUpdate}',   'Department:update',      'Update a department'),
                    ('{PermDepartmentDelete}',   'Department:delete',      'Delete a department'),
                    ('{PermTenantList}',         'Tenant:list',            'List tenants'),
                    ('{PermTenantRead}',         'Tenant:read',            'Read a tenant''s details'),
                    ('{PermTenantCreate}',       'Tenant:create',          'Create a new tenant'),
                    ('{PermTenantUpdate}',       'Tenant:update',          'Update a tenant'),
                    ('{PermTenantDelete}',       'Tenant:delete',          'Delete a tenant'),
                    ('{PermPolicyList}',         'Policy:list',            'List ABAC policies'),
                    ('{PermPolicyRead}',         'Policy:read',            'Read an ABAC policy''s details'),
                    ('{PermPolicyCreate}',       'Policy:create',          'Create a new ABAC policy'),
                    ('{PermPolicyUpdate}',       'Policy:update',          'Update an ABAC policy'),
                    ('{PermPolicyDelete}',       'Policy:delete',          'Delete an ABAC policy'),
                    ('{PermPlatformPolicyList}',   'Platform.Policy:list',   'List platform-level ABAC policies'),
                    ('{PermPlatformPolicyRead}',   'Platform.Policy:read',   'Read a platform-level ABAC policy'),
                    ('{PermPlatformPolicyCreate}', 'Platform.Policy:create', 'Create a platform-level ABAC policy'),
                    ('{PermPlatformPolicyUpdate}', 'Platform.Policy:update', 'Update a platform-level ABAC policy'),
                    ('{PermPlatformPolicyDelete}', 'Platform.Policy:delete', 'Delete a platform-level ABAC policy')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])
                """);

            // ── 5. Roles ───────────────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                DECLARE @now DATETIME2 = '{SeedDate}';
                INSERT INTO [auth].[Roles] ([Id], [Name], [Description], [TenantId], [CreatedBy], [CreatedAt], [UpdatedAt])
                SELECT v.[Id], v.[Name], v.[Description], '{IFXTenantId}', '{AdminUserId}', @now, @now
                FROM (VALUES
                    ('{RoleAdminId}',   'Admin',       'Administrator with full access'),
                    ('{RoleUserId}',    'User',        'Standard user with limited permissions'),
                    ('{RoleSsoUserId}', 'SsoUser',     'SSO authenticated user'),
                    ('{RolePendingId}', 'PendingUser', 'Pending user awaiting approval')
                ) AS v([Id], [Name], [Description])
                WHERE NOT EXISTS (SELECT 1 FROM [auth].[Roles] r WHERE r.[Id] = v.[Id])
                """);

            // ── 6. RoleGroup ───────────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[RoleGroups] WHERE [Id] = '{RoleGroupTestId}')
                    INSERT INTO [auth].[RoleGroups] ([Id], [Name], [Description], [TenantId], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES ('{RoleGroupTestId}', 'TestGroup', 'Test role group', '{IFXTenantId}', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 7. RoleGroupRoles: TestGroup → Admin, User, SsoUser ───────────────
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

            // ── 8. RolePermissions: Admin all 45; User/SsoUser/Pending User:read ──
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

            // ── 9. Admin User (CreatedBy = self) ───────────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[Users] WHERE [Id] = '{AdminUserId}')
                    INSERT INTO [auth].[Users]
                        ([Id], [IsActive], [DisplayName], [PrimaryTenantId], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{AdminUserId}', 1, 'Xiaolong Feng', '{IFXTenantId}', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 10. Admin UserIdentity (CreatedBy = UserId) ────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[UserIdentities] WHERE [Id] = '{AdminUserIdentityId}')
                    INSERT INTO [auth].[UserIdentities]
                        ([Id], [UserId], [IdpId], [Issuer], [Subject], [Email],
                         [FirstName], [LastName], [PhoneNumber], [BirthDate],
                         [EmailVerified], [PhoneNumberVerified], [LastSyncedAt], [CreatedBy], [CreatedAt], [UpdatedAt])
                    VALUES
                        ('{AdminUserIdentityId}', '{AdminUserId}', '{IdpIfxCognitoId}',
                         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
                         '59cee488-6091-7036-dd07-e2519702a444',
                         'von12549@gmail.com',
                         'Xiaolong', 'Feng', '', '',
                         1, 0, '{SeedDate}', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 11. UserRoles: Admin → Admin role ──────────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserRoles]
                    WHERE [RolesId] = '{RoleAdminId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserRoles] ([RolesId], [UserId])
                    VALUES ('{RoleAdminId}', '{AdminUserId}')
                """);

            // ── 12. UserRoleGroups: Admin → TestGroup ──────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserRoleGroups]
                    WHERE [RoleGroupsId] = '{RoleGroupTestId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserRoleGroups] ([RoleGroupsId], [UserId])
                    VALUES ('{RoleGroupTestId}', '{AdminUserId}')
                """);

            // ── 13. UserTenants: Admin → IFX tenant ───────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserTenants]
                    WHERE [TenantsId] = '{IFXTenantId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserTenants] ([TenantsId], [UserId])
                    VALUES ('{IFXTenantId}', '{AdminUserId}')
                """);

            // ── 14. UserDepartments: Admin → Test dept ─────────────────────────────
            migrationBuilder.Sql($"""
                IF NOT EXISTS (
                    SELECT 1 FROM [auth].[UserDepartments]
                    WHERE [DepartmentsId] = '{TestDeptId}' AND [UserId] = '{AdminUserId}')
                    INSERT INTO [auth].[UserDepartments] ([DepartmentsId], [UserId])
                    VALUES ('{TestDeptId}', '{AdminUserId}')
                """);

            // ── 15. PolicyDefinitions — base (2 rows) ─────────────────────────────
            // IFX tenant: user/read "Read Own Profile"
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[PolicyDefinitions] WHERE [Id] = '{PolicyUserReadIFX}')
                    INSERT INTO [auth].[PolicyDefinitions]
                        ([Id], [TenantId], [Scope], [Name], [Description], [ResourceType], [Action],
                         [ConditionsJson], [IsActive], [CreatedById], [UpdatedById], [CreatedAt], [UpdatedAt])
                    VALUES (
                        '{PolicyUserReadIFX}', '{IFXTenantId}', 0,
                        'Read Own Profile',
                        'Allows a user to read their own profile within the same tenant.',
                        'user', 'read',
                        '{STCM}',
                        1, '{AdminUserId}', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // Platform-level: user/read "Read Own Profile (Platform Default)"
            migrationBuilder.Sql($"""
                IF NOT EXISTS (SELECT 1 FROM [auth].[PolicyDefinitions] WHERE [Id] = '{PolicyUserReadPlatform}')
                    INSERT INTO [auth].[PolicyDefinitions]
                        ([Id], [TenantId], [Scope], [Name], [Description], [ResourceType], [Action],
                         [ConditionsJson], [IsActive], [CreatedById], [UpdatedById], [CreatedAt], [UpdatedAt])
                    VALUES (
                        '{PolicyUserReadPlatform}', NULL, 1,
                        'Read Own Profile (Platform Default)',
                        'Platform-wide default: allows any user to read their own profile within the same tenant.',
                        'user', 'read',
                        '{STCM}',
                        1, '{AdminUserId}', '{AdminUserId}', '{SeedDate}', '{SeedDate}')
                """);

            // ── 16. PolicyDefinitions — ABAC platform defaults (31 rows) ──────────
            // IDs kept from original SeedAbacPolicies — do not regenerate
            migrationBuilder.Sql($@"
DECLARE @UserId UNIQUEIDENTIFIER = '{AdminUserId}'
DECLARE @Now    DATETIME2        = '{SeedDate}'

INSERT INTO auth.PolicyDefinitions
    (Id, TenantId, Scope, Name, Description, ResourceType, Action, ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
SELECT v.Id, NULL, 1, v.Name, v.Description, v.ResourceType, v.Action, v.Conditions, 1, @UserId, @UserId, @Now, @Now
FROM (VALUES
    ('{PolicyUserUpdate}',       'Update Own Profile (Platform Default)',        'Allows a user to update their own profile within the same tenant.',                         'user',       'update',     '{STCM}'),
    ('{PolicyUserList}',         'List Users (Platform Default)',                'Allows listing all users within the same tenant.',                                          'user',       'list',       '{ST}'),
    ('{PolicyUserReadAdmin}',    'Read User Admin (Platform Default)',           'Allows reading any user profile within the same tenant.',                                   'user',       'read_admin', '{ST}'),
    ('{PolicyUserManage}',       'Manage User Assignments (Platform Default)',   'Allows assigning or removing roles, groups, and tenants for users within the same tenant.', 'user',       'manage',     '{ST}'),
    ('{PolicyRoleList}',         'List Roles (Platform Default)',                'Allows listing all roles within the same tenant.',                                          'role',       'list',       '{ST}'),
    ('{PolicyRoleRead}',         'Read Role (Platform Default)',                 'Allows reading a role within the same tenant.',                                             'role',       'read',       '{ST}'),
    ('{PolicyRoleCreate}',       'Create Role (Platform Default)',               'Allows creating a new role within the same tenant.',                                        'role',       'create',     '{ST}'),
    ('{PolicyRoleUpdate}',       'Update Role (Platform Default)',               'Allows updating a role within the same tenant.',                                            'role',       'update',     '{ST}'),
    ('{PolicyRoleDelete}',       'Delete Role (Platform Default)',               'Allows deleting a role within the same tenant.',                                            'role',       'delete',     '{ST}'),
    ('{PolicyRoleManage}',       'Manage Role Permissions (Platform Default)',   'Allows assigning or removing permissions on a role within the same tenant.',                'role',       'manage',     '{ST}'),
    ('{PolicyRoleGroupList}',    'List Role Groups (Platform Default)',          'Allows listing all role groups within the same tenant.',                                    'rolegroup',  'list',       '{ST}'),
    ('{PolicyRoleGroupRead}',    'Read Role Group (Platform Default)',           'Allows reading a role group within the same tenant.',                                       'rolegroup',  'read',       '{ST}'),
    ('{PolicyRoleGroupCreate}',  'Create Role Group (Platform Default)',         'Allows creating a new role group within the same tenant.',                                  'rolegroup',  'create',     '{ST}'),
    ('{PolicyRoleGroupUpdate}',  'Update Role Group (Platform Default)',         'Allows updating a role group within the same tenant.',                                      'rolegroup',  'update',     '{ST}'),
    ('{PolicyRoleGroupDelete}',  'Delete Role Group (Platform Default)',         'Allows deleting a role group within the same tenant.',                                      'rolegroup',  'delete',     '{ST}'),
    ('{PolicyRoleGroupManage}',  'Manage Role Group Members (Platform Default)', 'Allows assigning or removing roles within a role group in the same tenant.',               'rolegroup',  'manage',     '{ST}'),
    ('{PolicyDepartmentList}',   'List Departments (Platform Default)',          'Allows listing all departments within the same tenant.',                                    'department', 'list',       '{ST}'),
    ('{PolicyDepartmentRead}',   'Read Department (Platform Default)',           'Allows reading a department within the same tenant.',                                       'department', 'read',       '{ST}'),
    ('{PolicyDepartmentCreate}', 'Create Department (Platform Default)',         'Allows creating a new department within the same tenant.',                                  'department', 'create',     '{ST}'),
    ('{PolicyDepartmentUpdate}', 'Update Department (Platform Default)',         'Allows updating a department within the same tenant.',                                      'department', 'update',     '{ST}'),
    ('{PolicyDepartmentDelete}', 'Delete Department (Platform Default)',         'Allows deleting a department within the same tenant.',                                      'department', 'delete',     '{ST}'),
    ('{PolicyDepartmentManage}', 'Manage Department Members (Platform Default)', 'Allows assigning or removing users within a department in the same tenant.',               'department', 'manage',     '{ST}'),
    ('{PolicyIdpList}',          'List Identity Providers (Platform Default)',   'Allows listing all identity providers within the same tenant.',                             'idp',        'list',       '{ST}'),
    ('{PolicyIdpRead}',          'Read Identity Provider (Platform Default)',    'Allows reading an identity provider within the same tenant.',                               'idp',        'read',       '{ST}'),
    ('{PolicyIdpCreate}',        'Create Identity Provider (Platform Default)',  'Allows creating a new identity provider within the same tenant.',                           'idp',        'create',     '{ST}'),
    ('{PolicyIdpUpdate}',        'Update Identity Provider (Platform Default)',  'Allows updating an identity provider within the same tenant.',                              'idp',        'update',     '{ST}'),
    ('{PolicyPolicyList}',       'List Policies (Platform Default)',             'Allows listing all ABAC policies within the same tenant.',                                  'policy',     'list',       '{ST}'),
    ('{PolicyPolicyRead}',       'Read Policy (Platform Default)',               'Allows reading an ABAC policy within the same tenant.',                                     'policy',     'read',       '{ST}'),
    ('{PolicyPolicyCreate}',     'Create Policy (Platform Default)',             'Allows creating a new ABAC policy within the same tenant.',                                 'policy',     'create',     '{ST}'),
    ('{PolicyPolicyUpdate}',     'Update Policy (Platform Default)',             'Allows updating an ABAC policy within the same tenant.',                                    'policy',     'update',     '{ST}'),
    ('{PolicyPolicyDelete}',     'Delete Policy (Platform Default)',             'Allows deleting an ABAC policy within the same tenant.',                                    'policy',     'delete',     '{ST}')
) AS v(Id, Name, Description, ResourceType, Action, Conditions)
WHERE NOT EXISTS (SELECT 1 FROM auth.PolicyDefinitions p WHERE p.Id = v.Id)
");

            // ── 17. GlobalRoles (3) ────────────────────────────────────────────────
            migrationBuilder.Sql($"""
                INSERT INTO auth.GlobalRoles (Id, Name, Description, CreatedAt, UpdatedAt)
                SELECT '{PlatformAdminId}', 'PlatformAdmin', 'Full cross-tenant platform access', GETUTCDATE(), GETUTCDATE()
                WHERE NOT EXISTS (SELECT 1 FROM auth.GlobalRoles WHERE Id = '{PlatformAdminId}');

                INSERT INTO auth.GlobalRoles (Id, Name, Description, CreatedAt, UpdatedAt)
                SELECT '{PlatformSupportId}', 'PlatformSupport', 'Read-only cross-tenant support access', GETUTCDATE(), GETUTCDATE()
                WHERE NOT EXISTS (SELECT 1 FROM auth.GlobalRoles WHERE Id = '{PlatformSupportId}');

                INSERT INTO auth.GlobalRoles (Id, Name, Description, CreatedAt, UpdatedAt)
                SELECT '{PlatformAuditorId}', 'PlatformAuditor', 'Read-only audit access', GETUTCDATE(), GETUTCDATE()
                WHERE NOT EXISTS (SELECT 1 FROM auth.GlobalRoles WHERE Id = '{PlatformAuditorId}');
                """);

            // ── 18. PolicyDefinitions — PlatformSupport (14) + PlatformAuditor (7) ─
            migrationBuilder.Sql($@"
DECLARE @UserId UNIQUEIDENTIFIER = '{AdminUserId}'
DECLARE @Now    DATETIME2        = '{SeedDate}'

INSERT INTO auth.PolicyDefinitions
    (Id, TenantId, Scope, Name, Description, ResourceType, Action, ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
SELECT v.Id, NULL, 1, v.Name, v.Description, v.ResourceType, v.Action, v.Conditions, 1, @UserId, @UserId, @Now, @Now
FROM (VALUES
    -- PlatformSupport: list + read across all managed resources
    ('{PSup_UserList}',           'List Users (PlatformSupport)',              'PlatformSupport: list users cross-tenant.',                    'user',            'list',       '{GRI_SUPPORT}'),
    ('{PSup_UserRead}',           'Read User (PlatformSupport)',               'PlatformSupport: read any user profile cross-tenant.',         'user',            'read_admin', '{GRI_SUPPORT}'),
    ('{PSup_RoleList}',           'List Roles (PlatformSupport)',              'PlatformSupport: list roles cross-tenant.',                    'role',            'list',       '{GRI_SUPPORT}'),
    ('{PSup_RoleRead}',           'Read Role (PlatformSupport)',               'PlatformSupport: read any role cross-tenant.',                 'role',            'read',       '{GRI_SUPPORT}'),
    ('{PSup_RoleGroupList}',      'List Role Groups (PlatformSupport)',        'PlatformSupport: list role groups cross-tenant.',              'rolegroup',       'list',       '{GRI_SUPPORT}'),
    ('{PSup_RoleGroupRead}',      'Read Role Group (PlatformSupport)',         'PlatformSupport: read any role group cross-tenant.',           'rolegroup',       'read',       '{GRI_SUPPORT}'),
    ('{PSup_DepartmentList}',     'List Departments (PlatformSupport)',        'PlatformSupport: list departments cross-tenant.',              'department',      'list',       '{GRI_SUPPORT}'),
    ('{PSup_DepartmentRead}',     'Read Department (PlatformSupport)',         'PlatformSupport: read any department cross-tenant.',           'department',      'read',       '{GRI_SUPPORT}'),
    ('{PSup_IdpList}',            'List IdPs (PlatformSupport)',               'PlatformSupport: list identity providers cross-tenant.',       'idp',             'list',       '{GRI_SUPPORT}'),
    ('{PSup_IdpRead}',            'Read IdP (PlatformSupport)',                'PlatformSupport: read any identity provider cross-tenant.',    'idp',             'read',       '{GRI_SUPPORT}'),
    ('{PSup_PolicyList}',         'List Policies (PlatformSupport)',           'PlatformSupport: list ABAC policies cross-tenant.',            'policy',          'list',       '{GRI_SUPPORT}'),
    ('{PSup_PolicyRead}',         'Read Policy (PlatformSupport)',             'PlatformSupport: read any ABAC policy cross-tenant.',          'policy',          'read',       '{GRI_SUPPORT}'),
    ('{PSup_PlatformPolicyList}', 'List Platform Policies (PlatformSupport)', 'PlatformSupport: list platform-scoped ABAC policies.',         'platform_policy', 'list',       '{GRI_SUPPORT}'),
    ('{PSup_PlatformPolicyRead}', 'Read Platform Policy (PlatformSupport)',   'PlatformSupport: read any platform-scoped ABAC policy.',       'platform_policy', 'read',       '{GRI_SUPPORT}'),
    -- PlatformAuditor: list-only across all managed resources
    ('{PAud_UserList}',           'List Users (PlatformAuditor)',              'PlatformAuditor: list users cross-tenant (audit).',            'user',            'list',       '{GRI_AUDITOR}'),
    ('{PAud_RoleList}',           'List Roles (PlatformAuditor)',              'PlatformAuditor: list roles cross-tenant (audit).',            'role',            'list',       '{GRI_AUDITOR}'),
    ('{PAud_RoleGroupList}',      'List Role Groups (PlatformAuditor)',        'PlatformAuditor: list role groups cross-tenant (audit).',      'rolegroup',       'list',       '{GRI_AUDITOR}'),
    ('{PAud_DepartmentList}',     'List Departments (PlatformAuditor)',        'PlatformAuditor: list departments cross-tenant (audit).',      'department',      'list',       '{GRI_AUDITOR}'),
    ('{PAud_IdpList}',            'List IdPs (PlatformAuditor)',               'PlatformAuditor: list identity providers cross-tenant (audit).','idp',            'list',       '{GRI_AUDITOR}'),
    ('{PAud_PolicyList}',         'List Policies (PlatformAuditor)',           'PlatformAuditor: list ABAC policies cross-tenant (audit).',    'policy',          'list',       '{GRI_AUDITOR}'),
    ('{PAud_PlatformPolicyList}', 'List Platform Policies (PlatformAuditor)', 'PlatformAuditor: list platform-scoped ABAC policies (audit).', 'platform_policy', 'list',       '{GRI_AUDITOR}')
) AS v(Id, Name, Description, ResourceType, Action, Conditions)
WHERE NOT EXISTS (SELECT 1 FROM auth.PolicyDefinitions p WHERE p.Id = v.Id)
");

            // ── 19. UserGlobalRoles: Admin → PlatformAdmin ─────────────────────────
            migrationBuilder.Sql($"""
                INSERT INTO auth.UserGlobalRoles (UserId, GlobalRoleId, AssignedAt)
                SELECT '{AdminUserId}', '{PlatformAdminId}', GETUTCDATE()
                WHERE NOT EXISTS (
                    SELECT 1 FROM auth.UserGlobalRoles x
                    WHERE x.UserId = '{AdminUserId}' AND x.GlobalRoleId = '{PlatformAdminId}'
                );
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // ── Reverse order ──────────────────────────────────────────────────────

            // 19. UserGlobalRoles
            migrationBuilder.Sql($"DELETE FROM [auth].[UserGlobalRoles] WHERE [UserId] = '{AdminUserId}'");

            // 18. PlatformSupport + PlatformAuditor policies
            migrationBuilder.Sql($@"
DELETE FROM auth.PolicyDefinitions WHERE Id IN (
    '{PSup_UserList}', '{PSup_UserRead}',
    '{PSup_RoleList}', '{PSup_RoleRead}',
    '{PSup_RoleGroupList}', '{PSup_RoleGroupRead}',
    '{PSup_DepartmentList}', '{PSup_DepartmentRead}',
    '{PSup_IdpList}', '{PSup_IdpRead}',
    '{PSup_PolicyList}', '{PSup_PolicyRead}',
    '{PSup_PlatformPolicyList}', '{PSup_PlatformPolicyRead}',
    '{PAud_UserList}', '{PAud_RoleList}', '{PAud_RoleGroupList}',
    '{PAud_DepartmentList}', '{PAud_IdpList}',
    '{PAud_PolicyList}', '{PAud_PlatformPolicyList}'
)");

            // 17. GlobalRoles
            migrationBuilder.Sql($"""
                DELETE FROM auth.GlobalRoles
                WHERE Id IN ('{PlatformAdminId}', '{PlatformSupportId}', '{PlatformAuditorId}');
                """);

            // 16. ABAC platform defaults (31 rows)
            migrationBuilder.Sql($@"
DELETE FROM auth.PolicyDefinitions WHERE Id IN (
    '{PolicyUserUpdate}', '{PolicyUserList}', '{PolicyUserReadAdmin}', '{PolicyUserManage}',
    '{PolicyRoleList}', '{PolicyRoleRead}', '{PolicyRoleCreate}', '{PolicyRoleUpdate}', '{PolicyRoleDelete}', '{PolicyRoleManage}',
    '{PolicyRoleGroupList}', '{PolicyRoleGroupRead}', '{PolicyRoleGroupCreate}', '{PolicyRoleGroupUpdate}', '{PolicyRoleGroupDelete}', '{PolicyRoleGroupManage}',
    '{PolicyDepartmentList}', '{PolicyDepartmentRead}', '{PolicyDepartmentCreate}', '{PolicyDepartmentUpdate}', '{PolicyDepartmentDelete}', '{PolicyDepartmentManage}',
    '{PolicyIdpList}', '{PolicyIdpRead}', '{PolicyIdpCreate}', '{PolicyIdpUpdate}',
    '{PolicyPolicyList}', '{PolicyPolicyRead}', '{PolicyPolicyCreate}', '{PolicyPolicyUpdate}', '{PolicyPolicyDelete}'
)");

            // 15. Base PolicyDefinitions
            migrationBuilder.Sql($"DELETE FROM [auth].[PolicyDefinitions] WHERE [Id] IN ('{PolicyUserReadIFX}', '{PolicyUserReadPlatform}')");

            // 14. UserDepartments
            migrationBuilder.Sql($"DELETE FROM [auth].[UserDepartments] WHERE [UserId] = '{AdminUserId}'");

            // 13. UserTenants
            migrationBuilder.Sql($"DELETE FROM [auth].[UserTenants] WHERE [UserId] = '{AdminUserId}'");

            // 12. UserRoleGroups
            migrationBuilder.Sql($"DELETE FROM [auth].[UserRoleGroups] WHERE [UserId] = '{AdminUserId}'");

            // 11. UserRoles
            migrationBuilder.Sql($"DELETE FROM [auth].[UserRoles] WHERE [UserId] = '{AdminUserId}'");

            // 10. UserIdentity
            migrationBuilder.Sql($"DELETE FROM [auth].[UserIdentities] WHERE [Id] = '{AdminUserIdentityId}'");

            // 9. User
            migrationBuilder.Sql($"DELETE FROM [auth].[Users] WHERE [Id] = '{AdminUserId}'");

            // 8. RolePermissions
            migrationBuilder.Sql($"DELETE FROM [auth].[RolePermissions] WHERE [RoleId] IN ('{RoleAdminId}', '{RoleUserId}', '{RoleSsoUserId}', '{RolePendingId}')");

            // 7. RoleGroupRoles
            migrationBuilder.Sql($"DELETE FROM [auth].[RoleGroupRoles] WHERE [RoleGroupId] = '{RoleGroupTestId}'");

            // 6. RoleGroup
            migrationBuilder.Sql($"DELETE FROM [auth].[RoleGroups] WHERE [Id] = '{RoleGroupTestId}'");

            // 5. Roles
            migrationBuilder.Sql($"DELETE FROM [auth].[Roles] WHERE [Id] IN ('{RoleAdminId}', '{RoleUserId}', '{RoleSsoUserId}', '{RolePendingId}')");

            // 4. Permissions
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

            // 3. IdPs
            migrationBuilder.Sql($"DELETE FROM [auth].[Idps] WHERE [Id] IN ('{IdpIfxCognitoId}', '{IdpTestExternalId}', '{IdpVonCognitoId}')");

            // 2. Department
            migrationBuilder.Sql($"DELETE FROM [auth].[Departments] WHERE [Id] = '{TestDeptId}'");

            // 1. Tenant
            migrationBuilder.Sql($"DELETE FROM [auth].[Tenants] WHERE [Id] = '{IFXTenantId}'");
        }
    }
}

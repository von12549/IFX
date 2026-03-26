using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedGlobalRolePlatformPolicies : Migration
    {
        // Condition JSON fragments — GlobalRoleIncludes with global_role parameter
        private const string GRI_SUPPORT = @"[{""TemplateName"":""GlobalRoleIncludes"",""Parameters"":{""global_role"":""PlatformSupport""}}]";
        private const string GRI_AUDITOR = @"[{""TemplateName"":""GlobalRoleIncludes"",""Parameters"":{""global_role"":""PlatformAuditor""}}]";

        // Stable UUID v7 IDs — never regenerate
        // PlatformSupport policies
        private const string PSup_UserList            = "019D8000-0001-7000-8000-000000000001";
        private const string PSup_UserRead            = "019D8000-0001-7000-8000-000000000002";
        private const string PSup_RoleList            = "019D8000-0001-7000-8000-000000000003";
        private const string PSup_RoleRead            = "019D8000-0001-7000-8000-000000000004";
        private const string PSup_RoleGroupList       = "019D8000-0001-7000-8000-000000000005";
        private const string PSup_RoleGroupRead       = "019D8000-0001-7000-8000-000000000006";
        private const string PSup_DepartmentList      = "019D8000-0001-7000-8000-000000000007";
        private const string PSup_DepartmentRead      = "019D8000-0001-7000-8000-000000000008";
        private const string PSup_IdpList             = "019D8000-0001-7000-8000-000000000009";
        private const string PSup_IdpRead             = "019D8000-0001-7000-8000-00000000000A";
        private const string PSup_PolicyList          = "019D8000-0001-7000-8000-00000000000B";
        private const string PSup_PolicyRead          = "019D8000-0001-7000-8000-00000000000C";
        private const string PSup_PlatformPolicyList  = "019D8000-0001-7000-8000-00000000000D";
        private const string PSup_PlatformPolicyRead  = "019D8000-0001-7000-8000-00000000000E";

        // PlatformAuditor policies
        private const string PAud_UserList            = "019D8000-0002-7000-8000-000000000001";
        private const string PAud_RoleList            = "019D8000-0002-7000-8000-000000000002";
        private const string PAud_RoleGroupList       = "019D8000-0002-7000-8000-000000000003";
        private const string PAud_DepartmentList      = "019D8000-0002-7000-8000-000000000004";
        private const string PAud_IdpList             = "019D8000-0002-7000-8000-000000000005";
        private const string PAud_PolicyList          = "019D8000-0002-7000-8000-000000000006";
        private const string PAud_PlatformPolicyList  = "019D8000-0002-7000-8000-000000000007";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($@"
DECLARE @UserId UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
DECLARE @Now    DATETIME2        = GETUTCDATE()

INSERT INTO auth.PolicyDefinitions
    (Id, TenantId, Scope, Name, Description, ResourceType, Action, ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
SELECT v.Id, NULL, 1, v.Name, v.Description, v.ResourceType, v.Action, v.Conditions, 1, @UserId, @UserId, @Now, @Now
FROM (VALUES
    -- PlatformSupport: list + read across all managed resources
    ('{PSup_UserList}',           'List Users (PlatformSupport)',              'PlatformSupport: list users cross-tenant.',                    'user',            'list',    '{GRI_SUPPORT}'),
    ('{PSup_UserRead}',           'Read User (PlatformSupport)',               'PlatformSupport: read any user profile cross-tenant.',         'user',            'read_admin', '{GRI_SUPPORT}'),
    ('{PSup_RoleList}',           'List Roles (PlatformSupport)',              'PlatformSupport: list roles cross-tenant.',                    'role',            'list',    '{GRI_SUPPORT}'),
    ('{PSup_RoleRead}',           'Read Role (PlatformSupport)',               'PlatformSupport: read any role cross-tenant.',                 'role',            'read',    '{GRI_SUPPORT}'),
    ('{PSup_RoleGroupList}',      'List Role Groups (PlatformSupport)',        'PlatformSupport: list role groups cross-tenant.',              'rolegroup',       'list',    '{GRI_SUPPORT}'),
    ('{PSup_RoleGroupRead}',      'Read Role Group (PlatformSupport)',         'PlatformSupport: read any role group cross-tenant.',           'rolegroup',       'read',    '{GRI_SUPPORT}'),
    ('{PSup_DepartmentList}',     'List Departments (PlatformSupport)',        'PlatformSupport: list departments cross-tenant.',              'department',      'list',    '{GRI_SUPPORT}'),
    ('{PSup_DepartmentRead}',     'Read Department (PlatformSupport)',         'PlatformSupport: read any department cross-tenant.',           'department',      'read',    '{GRI_SUPPORT}'),
    ('{PSup_IdpList}',            'List IdPs (PlatformSupport)',               'PlatformSupport: list identity providers cross-tenant.',       'idp',             'list',    '{GRI_SUPPORT}'),
    ('{PSup_IdpRead}',            'Read IdP (PlatformSupport)',                'PlatformSupport: read any identity provider cross-tenant.',    'idp',             'read',    '{GRI_SUPPORT}'),
    ('{PSup_PolicyList}',         'List Policies (PlatformSupport)',           'PlatformSupport: list ABAC policies cross-tenant.',            'policy',          'list',    '{GRI_SUPPORT}'),
    ('{PSup_PolicyRead}',         'Read Policy (PlatformSupport)',             'PlatformSupport: read any ABAC policy cross-tenant.',          'policy',          'read',    '{GRI_SUPPORT}'),
    ('{PSup_PlatformPolicyList}', 'List Platform Policies (PlatformSupport)', 'PlatformSupport: list platform-scoped ABAC policies.',         'platform_policy', 'list',    '{GRI_SUPPORT}'),
    ('{PSup_PlatformPolicyRead}', 'Read Platform Policy (PlatformSupport)',   'PlatformSupport: read any platform-scoped ABAC policy.',       'platform_policy', 'read',    '{GRI_SUPPORT}'),
    -- PlatformAuditor: list-only across all managed resources
    ('{PAud_UserList}',           'List Users (PlatformAuditor)',              'PlatformAuditor: list users cross-tenant (audit).',            'user',            'list',    '{GRI_AUDITOR}'),
    ('{PAud_RoleList}',           'List Roles (PlatformAuditor)',              'PlatformAuditor: list roles cross-tenant (audit).',            'role',            'list',    '{GRI_AUDITOR}'),
    ('{PAud_RoleGroupList}',      'List Role Groups (PlatformAuditor)',        'PlatformAuditor: list role groups cross-tenant (audit).',      'rolegroup',       'list',    '{GRI_AUDITOR}'),
    ('{PAud_DepartmentList}',     'List Departments (PlatformAuditor)',        'PlatformAuditor: list departments cross-tenant (audit).',      'department',      'list',    '{GRI_AUDITOR}'),
    ('{PAud_IdpList}',            'List IdPs (PlatformAuditor)',               'PlatformAuditor: list identity providers cross-tenant (audit).','idp',            'list',    '{GRI_AUDITOR}'),
    ('{PAud_PolicyList}',         'List Policies (PlatformAuditor)',           'PlatformAuditor: list ABAC policies cross-tenant (audit).',    'policy',          'list',    '{GRI_AUDITOR}'),
    ('{PAud_PlatformPolicyList}', 'List Platform Policies (PlatformAuditor)', 'PlatformAuditor: list platform-scoped ABAC policies (audit).', 'platform_policy', 'list',    '{GRI_AUDITOR}')
) AS v(Id, Name, Description, ResourceType, Action, Conditions)
WHERE NOT EXISTS (SELECT 1 FROM auth.PolicyDefinitions p WHERE p.Id = v.Id)
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($@"
DELETE FROM auth.PolicyDefinitions
WHERE Id IN (
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
)
");
        }
    }
}

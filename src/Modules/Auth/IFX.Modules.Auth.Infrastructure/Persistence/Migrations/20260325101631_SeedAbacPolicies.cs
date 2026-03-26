using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedAbacPolicies : Migration
    {
        // Condition JSON fragments
        private const string ST   = @"[{""TemplateName"":""SameTenant"",""Parameters"":null}]";
        private const string STCM = @"[{""TemplateName"":""SameTenant"",""Parameters"":null},{""TemplateName"":""CreatedByMe"",""Parameters"":null}]";

        // Stable UUID v7 IDs generated once with Uuid.NewSequential() — do not regenerate
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

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Platform-level policies (TenantId IS NULL). user/read already seeded in InitialSeed.
            migrationBuilder.Sql($@"
DECLARE @UserId UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
DECLARE @Now    DATETIME2        = GETUTCDATE()

INSERT INTO auth.PolicyDefinitions
    (Id, TenantId, Name, Description, ResourceType, Action, ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
SELECT v.Id, NULL, v.Name, v.Description, v.ResourceType, v.Action, v.Conditions, 1, @UserId, @UserId, @Now, @Now
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql($@"
DELETE FROM auth.PolicyDefinitions
WHERE Id IN (
    '{PolicyUserUpdate}', '{PolicyUserList}', '{PolicyUserReadAdmin}', '{PolicyUserManage}',
    '{PolicyRoleList}', '{PolicyRoleRead}', '{PolicyRoleCreate}', '{PolicyRoleUpdate}', '{PolicyRoleDelete}', '{PolicyRoleManage}',
    '{PolicyRoleGroupList}', '{PolicyRoleGroupRead}', '{PolicyRoleGroupCreate}', '{PolicyRoleGroupUpdate}', '{PolicyRoleGroupDelete}', '{PolicyRoleGroupManage}',
    '{PolicyDepartmentList}', '{PolicyDepartmentRead}', '{PolicyDepartmentCreate}', '{PolicyDepartmentUpdate}', '{PolicyDepartmentDelete}', '{PolicyDepartmentManage}',
    '{PolicyIdpList}', '{PolicyIdpRead}', '{PolicyIdpCreate}', '{PolicyIdpUpdate}',
    '{PolicyPolicyList}', '{PolicyPolicyRead}', '{PolicyPolicyCreate}', '{PolicyPolicyUpdate}', '{PolicyPolicyDelete}'
)
");
        }
    }
}




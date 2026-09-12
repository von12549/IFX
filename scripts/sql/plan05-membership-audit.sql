-- Read-only; run before and after expansion against the authorized target database.
-- UserTenants is the sole membership source. These findings must never be repaired by inferring membership.
SELECT N'role_without_membership' AS Finding, ur.UserId, r.TenantId, ur.RolesId AS RelatedId
FROM auth.UserRoles ur JOIN auth.Roles r ON r.Id = ur.RolesId
WHERE NOT EXISTS (SELECT 1 FROM auth.UserTenants m WHERE m.UserId = ur.UserId AND m.TenantsId = r.TenantId)
UNION ALL
SELECT N'group_without_membership', ug.UserId, g.TenantId, ug.RoleGroupsId
FROM auth.UserRoleGroups ug JOIN auth.RoleGroups g ON g.Id = ug.RoleGroupsId
WHERE NOT EXISTS (SELECT 1 FROM auth.UserTenants m WHERE m.UserId = ug.UserId AND m.TenantsId = g.TenantId)
UNION ALL
SELECT N'department_without_membership', ud.UserId, d.TenantId, ud.DepartmentsId
FROM auth.UserDepartments ud JOIN auth.Departments d ON d.Id = ud.DepartmentsId
WHERE NOT EXISTS (SELECT 1 FROM auth.UserTenants m WHERE m.UserId = ud.UserId AND m.TenantsId = d.TenantId)
UNION ALL
SELECT N'primary_without_membership', u.Id, u.PrimaryTenantId, u.PrimaryTenantId
FROM auth.Users u WHERE u.PrimaryTenantId IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM auth.UserTenants m WHERE m.UserId = u.Id AND m.TenantsId = u.PrimaryTenantId)
UNION ALL
SELECT N'group_role_tenant_mismatch', CAST(NULL AS uniqueidentifier), g.TenantId, r.Id
FROM auth.RoleGroupRoles gr JOIN auth.RoleGroups g ON g.Id = gr.RoleGroupId JOIN auth.Roles r ON r.Id = gr.RolesId
WHERE g.TenantId <> r.TenantId;

SELECT N'UserTenants' AS Relation, COUNT_BIG(*) AS [RowCount] FROM auth.UserTenants
UNION ALL SELECT N'UserRoles', COUNT_BIG(*) FROM auth.UserRoles
UNION ALL SELECT N'UserRoleGroups', COUNT_BIG(*) FROM auth.UserRoleGroups
UNION ALL SELECT N'UserDepartments', COUNT_BIG(*) FROM auth.UserDepartments
UNION ALL SELECT N'UserGlobalRoles', COUNT_BIG(*) FROM auth.UserGlobalRoles;

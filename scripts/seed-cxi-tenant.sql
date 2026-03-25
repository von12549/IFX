-- =============================================================================
-- CXI Tenant Seed Script
-- =============================================================================
-- Optional, environment-specific seed data for the CXI tenant.
-- This is NOT part of the mandatory EF migrations (InitialSeed).
-- Run this manually against IFXDb on dev/staging environments as needed.
--
-- Safe to re-run: all inserts are guarded with IF NOT EXISTS.
--
-- Extracted from live database: 2026-03-25
-- =============================================================================

USE IFXDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- =============================================================================
-- Stable GUIDs
-- =============================================================================
-- Tenant
--   CXI:                      BBBBBBBB-0001-0000-0000-000000000001
-- Idp
--   CXI Cognito:              BBBBBBBB-0004-0000-0000-000000000001
-- Roles
--   CXI-Admin:                BBBBBBBB-0002-0000-0000-000000000001
--   CXI-User:                 BBBBBBBB-0002-0000-0000-000000000002
-- RoleGroups
--   CXI-Managers:             BBBBBBBB-0003-0000-0000-000000000001
--   CXI-Staff:                BBBBBBBB-0003-0000-0000-000000000002
-- Users
--   Xiaolong CxiSoftware:     8907538D-AC31-44AD-B78F-6FC585559AC9
--   UserIdentity:             ED684B02-6EA7-4EC5-944D-191AF0377E18
-- Also member of CXI tenant (already in InitialSeed):
--   Xiaolong Feng (admin):    8314F7DA-2F5D-4128-A705-957CE0C3972E
-- =============================================================================

PRINT 'Seeding CXI tenant...';

-- ── 1. Tenant ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM auth.Tenants WHERE Id = 'BBBBBBBB-0001-0000-0000-000000000001')
BEGIN
    INSERT INTO auth.Tenants (Id, Name, Description, CreatedAt, UpdatedAt)
    VALUES ('BBBBBBBB-0001-0000-0000-000000000001', 'CXI', 'CXI Software tenant',
            '2026-03-22 14:18:26', '2026-03-22 14:18:26');
    PRINT '  [+] Tenant: CXI';
END
ELSE PRINT '  [=] Tenant: CXI (already exists)';

-- ── 2. Idp ────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM auth.Idps WHERE Id = 'BBBBBBBB-0004-0000-0000-000000000001')
BEGIN
    INSERT INTO auth.Idps
        (Id, Name, Issuer, Authority, Description, LoginUrl,
         IdpType, IsPrimary, Enabled, AutoProvisionEnabled,
         TenantId, ExpectedAudiences, AllowedAlgs, RequiredScopes,
         ClaimMapping, ClockSkewSeconds, CreatedAt, UpdatedAt)
    VALUES
        ('BBBBBBBB-0004-0000-0000-000000000001',
         'CXI Cognito',
         'https://cognito-idp.ap-southeast-2.amazonaws.com/cxi-pool',
         'https://cognito-idp.ap-southeast-2.amazonaws.com/cxi-pool',
         'CXI AWS Cognito identity provider',
         'https://cxi.auth.ap-southeast-2.amazoncognito.com/login',
         'External', 0, 1, 1,
         'BBBBBBBB-0001-0000-0000-000000000001',
         '[]', '[]', '[]', '{}', 300,
         '2026-03-22 14:18:26', '2026-03-22 14:18:26');
    PRINT '  [+] Idp: CXI Cognito';
END
ELSE PRINT '  [=] Idp: CXI Cognito (already exists)';

-- ── 3. Roles ──────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM auth.Roles WHERE Id = 'BBBBBBBB-0002-0000-0000-000000000001')
BEGIN
    INSERT INTO auth.Roles (Id, Name, Description, TenantId, CreatedAt, UpdatedAt)
    VALUES ('BBBBBBBB-0002-0000-0000-000000000001', 'CXI-Admin', 'CXI administrator role',
            'BBBBBBBB-0001-0000-0000-000000000001', '2026-03-22 14:18:26', '2026-03-22 14:18:26');
    PRINT '  [+] Role: CXI-Admin';
END
ELSE PRINT '  [=] Role: CXI-Admin (already exists)';

IF NOT EXISTS (SELECT 1 FROM auth.Roles WHERE Id = 'BBBBBBBB-0002-0000-0000-000000000002')
BEGIN
    INSERT INTO auth.Roles (Id, Name, Description, TenantId, CreatedAt, UpdatedAt)
    VALUES ('BBBBBBBB-0002-0000-0000-000000000002', 'CXI-User', 'CXI standard user role',
            'BBBBBBBB-0001-0000-0000-000000000001', '2026-03-22 14:18:26', '2026-03-22 14:18:26');
    PRINT '  [+] Role: CXI-User';
END
ELSE PRINT '  [=] Role: CXI-User (already exists)';

-- ── 4. RoleGroups ─────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM auth.RoleGroups WHERE Id = 'BBBBBBBB-0003-0000-0000-000000000001')
BEGIN
    INSERT INTO auth.RoleGroups (Id, Name, Description, TenantId, CreatedAt, UpdatedAt)
    VALUES ('BBBBBBBB-0003-0000-0000-000000000001', 'CXI-Managers', 'CXI management team group',
            'BBBBBBBB-0001-0000-0000-000000000001', '2026-03-22 14:18:26', '2026-03-22 14:18:26');
    PRINT '  [+] RoleGroup: CXI-Managers';
END
ELSE PRINT '  [=] RoleGroup: CXI-Managers (already exists)';

IF NOT EXISTS (SELECT 1 FROM auth.RoleGroups WHERE Id = 'BBBBBBBB-0003-0000-0000-000000000002')
BEGIN
    INSERT INTO auth.RoleGroups (Id, Name, Description, TenantId, CreatedAt, UpdatedAt)
    VALUES ('BBBBBBBB-0003-0000-0000-000000000002', 'CXI-Staff', 'CXI general staff group',
            'BBBBBBBB-0001-0000-0000-000000000001', '2026-03-22 14:18:26', '2026-03-22 14:18:26');
    PRINT '  [+] RoleGroup: CXI-Staff';
END
ELSE PRINT '  [=] RoleGroup: CXI-Staff (already exists)';

-- ── 5. RoleGroupRoles ─────────────────────────────────────────────────────────
-- CXI-Managers -> CXI-Admin, CXI-User
-- CXI-Staff    -> CXI-User
INSERT INTO auth.RoleGroupRoles (RoleGroupId, RolesId)
SELECT v.RoleGroupId, v.RolesId
FROM (VALUES
    ('BBBBBBBB-0003-0000-0000-000000000001', 'BBBBBBBB-0002-0000-0000-000000000001'), -- CXI-Managers -> CXI-Admin
    ('BBBBBBBB-0003-0000-0000-000000000001', 'BBBBBBBB-0002-0000-0000-000000000002'), -- CXI-Managers -> CXI-User
    ('BBBBBBBB-0003-0000-0000-000000000002', 'BBBBBBBB-0002-0000-0000-000000000002')  -- CXI-Staff    -> CXI-User
) AS v(RoleGroupId, RolesId)
WHERE NOT EXISTS (
    SELECT 1 FROM auth.RoleGroupRoles x
    WHERE x.RoleGroupId = v.RoleGroupId AND x.RolesId = v.RolesId);

PRINT '  [+] RoleGroupRoles: CXI-Managers->CXI-Admin, CXI-Managers->CXI-User, CXI-Staff->CXI-User';

-- ── 6. CXI-specific user: Xiaolong CxiSoftware ───────────────────────────────
IF NOT EXISTS (SELECT 1 FROM auth.Users WHERE Id = '8907538D-AC31-44AD-B78F-6FC585559AC9')
BEGIN
    INSERT INTO auth.Users (Id, IsActive, DisplayName, PrimaryTenantId, CreatedAt, UpdatedAt)
    VALUES ('8907538D-AC31-44AD-B78F-6FC585559AC9', 1, 'Xiaolong CxiSoftware',
            'BBBBBBBB-0001-0000-0000-000000000001',
            '2026-03-21 14:09:39', '2026-03-21 16:37:59');
    PRINT '  [+] User: Xiaolong CxiSoftware';
END
ELSE PRINT '  [=] User: Xiaolong CxiSoftware (already exists)';

-- UserIdentity (linked to IFX Cognito — same Cognito pool, different subject)
IF NOT EXISTS (SELECT 1 FROM auth.UserIdentities WHERE Id = 'ED684B02-6EA7-4EC5-944D-191AF0377E18')
BEGIN
    INSERT INTO auth.UserIdentities
        (Id, UserId, IdpId, Issuer, Subject, Email,
         FirstName, LastName, PhoneNumber, BirthDate,
         EmailVerified, PhoneNumberVerified, LastSyncedAt, CreatedAt, UpdatedAt)
    VALUES
        ('ED684B02-6EA7-4EC5-944D-191AF0377E18',
         '8907538D-AC31-44AD-B78F-6FC585559AC9',
         'B1B2C3D4-0002-0000-0000-000000000001',   -- IFX Cognito IdP
         'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_nh141gzCi',
         'a98e04a8-80b1-7092-4088-60c30e961d5d',
         'xiaolong@cxisoftware.com.au',
         'Xiaolong', 'CxiSoftware', '', '',
         1, 0,
         '2026-03-21 14:09:39', '2026-03-21 14:09:39', '2026-03-21 16:37:59');
    PRINT '  [+] UserIdentity: Xiaolong CxiSoftware';
END
ELSE PRINT '  [=] UserIdentity: Xiaolong CxiSoftware (already exists)';

-- ── 7. UserTenants ────────────────────────────────────────────────────────────
-- Xiaolong CxiSoftware -> CXI
IF NOT EXISTS (
    SELECT 1 FROM auth.UserTenants
    WHERE TenantsId = 'BBBBBBBB-0001-0000-0000-000000000001'
      AND UserId    = '8907538D-AC31-44AD-B78F-6FC585559AC9')
BEGIN
    INSERT INTO auth.UserTenants (TenantsId, UserId)
    VALUES ('BBBBBBBB-0001-0000-0000-000000000001', '8907538D-AC31-44AD-B78F-6FC585559AC9');
    PRINT '  [+] UserTenant: Xiaolong CxiSoftware -> CXI';
END
ELSE PRINT '  [=] UserTenant: Xiaolong CxiSoftware -> CXI (already exists)';

-- Xiaolong Feng (admin, from InitialSeed) -> CXI
-- This assumes the admin user already exists from InitialSeed.
IF EXISTS (SELECT 1 FROM auth.Users WHERE Id = '8314F7DA-2F5D-4128-A705-957CE0C3972E')
   AND NOT EXISTS (
       SELECT 1 FROM auth.UserTenants
       WHERE TenantsId = 'BBBBBBBB-0001-0000-0000-000000000001'
         AND UserId    = '8314F7DA-2F5D-4128-A705-957CE0C3972E')
BEGIN
    INSERT INTO auth.UserTenants (TenantsId, UserId)
    VALUES ('BBBBBBBB-0001-0000-0000-000000000001', '8314F7DA-2F5D-4128-A705-957CE0C3972E');
    PRINT '  [+] UserTenant: Xiaolong Feng (admin) -> CXI';
END
ELSE PRINT '  [=] UserTenant: Xiaolong Feng (admin) -> CXI (already exists or admin user missing)';

PRINT 'CXI tenant seed complete.';
GO

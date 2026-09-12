-- Read-only Plan 05 v2 classification; run against the explicitly selected target before rollout.
-- Preserve ConditionsJson/Scope/row identity. This query neither rewrites policies nor enables membership.
-- Persist the result in the target-environment evidence store with restricted access (IDs are C2).
WITH classified AS (
    SELECT p.Id, p.TenantId, p.Scope, p.ResourceType, p.Action, p.IsActive, p.UpdatedAt,
           CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), p.ConditionsJson)), 2) AS OriginalPolicyHash,
           CASE WHEN ISJSON(p.ConditionsJson) <> 1 THEN 'invalid-json'
                WHEN p.Scope = 0 AND p.TenantId IS NOT NULL THEN 'tenant-custom'
                WHEN p.Scope = 1 AND p.TenantId IS NULL AND EXISTS (
                    SELECT 1 FROM OPENJSON(CASE WHEN ISJSON(p.ConditionsJson) = 1 THEN p.ConditionsJson ELSE '[]' END)
                    WITH (TemplateName nvarchar(100) '$.TemplateName') c WHERE c.TemplateName = 'GlobalRoleIncludes'
                ) THEN 'platform-role-grant'
                WHEN p.Scope = 1 AND p.TenantId IS NULL THEN 'overridable-default'
                ELSE 'invalid-scope' END AS PolicyClass
    FROM auth.PolicyDefinitions p
)
SELECT *, 'iam-semantics-v2' AS ClassificationVersion FROM classified ORDER BY Scope, TenantId, ResourceType, Action, Id;

-- Mandatory scope, authenticated actor and RBAC constraints are code-owned; no mutable row can remove them.
-- Resolver validation remains authoritative for unknown templates, invalid parameters and ambiguous selectors.

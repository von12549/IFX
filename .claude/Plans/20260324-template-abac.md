# Plan: Template-Based ABAC

**Date:** 2026-03-24
**Branch:** `feature/security/template-abac`
**Status:** Planned

## Goal

Extend `IFX.BuildingBlocks.Security` with a template-based ABAC engine that allows C#-defined reusable condition templates (Left / Operator / Right) to be evaluated by a single generic OPA Rego policy, replacing per-resource Rego files for new resource types. Existing pilot Rego policies remain untouched.

---

## Design Decisions

| Question | Decision |
|----------|----------|
| New project? | No — extend `IFX.BuildingBlocks.Security` only |
| `TemplateRegistry` scope | Interface + in-memory singleton; NOT a static class (testability) |
| `ParamType.UserInput` resolution | New `AuthorizeWithPolicyAsync` overload; `IDictionary<string,object>?` params argument |
| OPA envelope change | Add optional `conditions` field to existing `OpaAuthorizationEnvelope<TResource>` — null = old path unchanged |
| Backward compat | Keep `read-user.rego` and `manage-role.rego`; they route to their own paths. New resources use `authz/common/abac_eval` |
| `SameDepartment` operator | Requires `Intersects` operator (set-overlap), not `Equals` |
| `IResourceAuthorizationService` interface | Add new overload; do NOT modify existing `AuthorizeAsync` signature |

---

## Folder Structure

```
IFX.BuildingBlocks.Security/
  Authorization/
    Abac/
      Templates/
        ConditionTemplate.cs         # Named reusable blueprint (Left/Operator/Right)
        ConditionOperator.cs         # enum: Equals, NotEquals, In, NotIn, Contains, Intersects
        ConditionValueRef.cs         # Right-hand side descriptor: Literal | FieldRef | UserInput
        ValueRefType.cs              # enum: Literal, FieldRef, UserInput
      Policies/
        AbacCondition.cs             # Template + resolved Right value (after UserInput substitution)
        AbacPolicy.cs                # List<AbacCondition> for one (resourceType, action) pair
        ResolvedCondition.cs         # Serializable condition sent inside OPA input
      Registry/
        IAbacTemplateRegistry.cs     # Interface: Register / Resolve
        AbacTemplateRegistry.cs      # InMemoryAbacTemplateRegistry (singleton)
        BuiltInTemplates.cs          # SameDepartment, CreatedByMe template definitions
      Engine/
        IAbacPolicyEngine.cs         # Interface: Resolve(policy, parameters) → List<ResolvedCondition>
        AbacPolicyEngine.cs          # Resolves UserInput params; converts AbacPolicy → ResolvedCondition[]
```

---

## Step-by-Step Implementation

### Step 1 — Value types

**`ValueRefType.cs`**
```csharp
public enum ValueRefType
{
    Literal,     // fixed value baked into the template
    FieldRef,    // path into the OPA input (e.g. "subject.id")
    UserInput    // resolved from caller-supplied parameters dict at runtime
}
```

**`ConditionOperator.cs`**
```csharp
public enum ConditionOperator
{
    Equals,
    NotEquals,
    In,          // scalar is member of a collection
    NotIn,
    Contains,    // collection contains a scalar
    Intersects   // two collections share at least one element
}
```

**`ConditionValueRef.cs`**
```csharp
public class ConditionValueRef
{
    public ValueRefType Type { get; init; }
    public string Value { get; init; } = string.Empty;  // literal value, field path, or param key
}
```

---

### Step 2 — ConditionTemplate

```csharp
public class ConditionTemplate
{
    public string Name { get; init; } = string.Empty;   // e.g. "SameDepartment"
    public string Left { get; init; } = string.Empty;   // OPA input field path (e.g. "subject.departments")
    public ConditionOperator Operator { get; init; }
    public ConditionValueRef Right { get; init; } = null!;
}
```

---

### Step 3 — AbacCondition and AbacPolicy

**`AbacCondition.cs`** — A template with optional runtime overrides:
```csharp
public class AbacCondition
{
    public ConditionTemplate Template { get; init; } = null!;
    public IDictionary<string, object>? Parameters { get; init; }  // UserInput resolution
}
```

**`AbacPolicy.cs`**
```csharp
public class AbacPolicy
{
    public string ResourceType { get; init; } = string.Empty;
    public string Action { get; init; } = string.Empty;
    public IReadOnlyList<AbacCondition> Conditions { get; init; } = [];
}
```

**`ResolvedCondition.cs`** — serializable; goes into OPA input:
```csharp
public class ResolvedCondition
{
    [JsonPropertyName("left")]
    public string Left { get; init; } = string.Empty;

    [JsonPropertyName("operator")]
    public string Operator { get; init; } = string.Empty;

    [JsonPropertyName("right_type")]
    public string RightType { get; init; } = string.Empty;   // "literal" | "field_ref"

    [JsonPropertyName("right")]
    public string Right { get; init; } = string.Empty;
}
```

`UserInput` is always resolved to `Literal` or `FieldRef` before serialization. `UserInput` type never reaches OPA.

---

### Step 4 — IAbacTemplateRegistry and implementation

**`IAbacTemplateRegistry.cs`**
```csharp
public interface IAbacTemplateRegistry
{
    void Register(string templateName, ConditionTemplate template);
    ConditionTemplate Resolve(string templateName);
    bool TryResolve(string templateName, out ConditionTemplate? template);
}
```

**`AbacTemplateRegistry.cs`** — thread-safe in-memory singleton:
- `ConcurrentDictionary<string, ConditionTemplate>` backing store
- `Resolve` throws `InvalidOperationException` for unknown template names (fail-fast)

**`BuiltInTemplates.cs`** — registers initial templates:

| Name | Left | Operator | Right |
|------|------|----------|-------|
| `SameDepartment` | `subject.departments` | `Intersects` | FieldRef `resource.departments` |
| `CreatedByMe` | `subject.id` | `Equals` | FieldRef `resource.owner_id` |
| `SameTenant` | `subject.tenant_id` | `Equals` | FieldRef `resource.tenant_id` |

`BuiltInTemplates.Register(IAbacTemplateRegistry registry)` called at DI startup.

---

### Step 5 — AbacPolicyEngine

**`IAbacPolicyEngine.cs`**
```csharp
public interface IAbacPolicyEngine
{
    IReadOnlyList<ResolvedCondition> Resolve(
        AbacPolicy policy,
        IDictionary<string, object>? parameters = null);
}
```

**`AbacPolicyEngine.cs`** — resolution logic:
1. For each `AbacCondition` in the policy:
   - Get `ConditionTemplate` from registry (or use inline template)
   - Evaluate `Right.Type`:
     - `Literal` → use `Right.Value` directly
     - `FieldRef` → use `Right.Value` directly (OPA resolves the field path)
     - `UserInput` → look up `Right.Value` key in `parameters` dict; throw `ArgumentException` if missing
   - Produce `ResolvedCondition { Left, Operator (snake_case), RightType, Right }`
2. Return list

---

### Step 6 — OpaAuthorizationEnvelope extension

Add optional `Conditions` field to existing `OpaAuthorizationEnvelope<TResource>`:

```csharp
[JsonPropertyName("conditions")]
[JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
public IReadOnlyList<ResolvedCondition>? Conditions { get; init; }
```

Existing callers that don't set this field → `null` → ignored in JSON → existing Rego policies unaffected.

---

### Step 7 — IResourceAuthorizationService new overload

Add to `IResourceAuthorizationService`:
```csharp
Task AuthorizeWithPolicyAsync<TResource>(
    AbacPolicy policy,
    TResource resourceAttributes,
    IDictionary<string, object>? parameters = null,
    CancellationToken ct = default)
    where TResource : OpaResourceAttributesBase;
```

**Decision path for template-based resources:** always `"authz/common/abac_eval"`.

**`ResourceAuthorizationService` implementation:**
1. RBAC gate: `policy` has no `requiredPermission` field — RBAC is skipped (consistent with nullable pattern from existing design). If RBAC is needed, caller uses the existing `AuthorizeAsync` overload first.
2. Call `AbacPolicyEngine.Resolve(policy, parameters)` → `IReadOnlyList<ResolvedCondition>`
3. Build `OpaAuthorizationEnvelope<TResource>` with `Conditions` populated
4. Call `_opaClient.EvaluateAsync("authz/common/abac_eval", envelope, ct)`
5. Throw `ForbiddenException` on deny

---

### Step 8 — Generic Rego policy: authz/common/abac_eval.rego

Location: `policies/authz/common/abac_eval.rego`

```rego
package authz.common.abac_eval

import future.keywords

default allow := false

# Allow when all conditions evaluate to true
allow if {
    count(input.conditions) > 0
    every condition in input.conditions {
        condition_passes(condition)
    }
}

# Equals: resolve both sides and compare
condition_passes(c) if {
    c.operator == "equals"
    resolve(c.left) == resolve_right(c)
}

condition_passes(c) if {
    c.operator == "not_equals"
    resolve(c.left) != resolve_right(c)
}

condition_passes(c) if {
    c.operator == "in"
    resolve(c.left) in resolve_right(c)
}

condition_passes(c) if {
    c.operator == "not_in"
    not resolve(c.left) in resolve_right(c)
}

condition_passes(c) if {
    c.operator == "intersects"
    some item in resolve(c.left)
    item in resolve_right(c)
}

# Resolve a dot-path against input (supports subject.X and resource.X)
resolve(path) := input.subject[field] if {
    parts := split(path, ".")
    parts[0] == "subject"
    field := parts[1]
}

resolve(path) := input.resource[field] if {
    parts := split(path, ".")
    parts[0] == "resource"
    field := parts[1]
}

# Resolve right-hand side based on right_type
resolve_right(c) := c.right if { c.right_type == "literal" }
resolve_right(c) := resolve(c.right) if { c.right_type == "field_ref" }
```

---

### Step 9 — Policy test: abac_eval_test.rego

Location: `policies/tests/common/abac_eval_test.rego`

Scenarios to cover:
- `SameDepartment` passes when subject and resource share a department
- `SameDepartment` denies when departments don't intersect
- `CreatedByMe` passes when `subject.id == resource.owner_id`
- `CreatedByMe` denies when IDs differ
- Empty conditions list → deny (no conditions = deny)
- Mixed: multiple conditions all pass → allow
- Mixed: one condition fails → deny

---

### Step 10 — DI Registration

In `Auth.Composition` (or wherever security services are wired):

```csharp
// Register ABAC engine
services.AddSingleton<IAbacTemplateRegistry, AbacTemplateRegistry>(sp =>
{
    var registry = new AbacTemplateRegistry();
    BuiltInTemplates.Register(registry);
    return registry;
});
services.AddScoped<IAbacPolicyEngine, AbacPolicyEngine>();
```

`ResourceAuthorizationService` constructor gains `IAbacPolicyEngine` via DI.

---

## Folder Summary — Files to Create

| File | Purpose |
|------|---------|
| `Authorization/Abac/Templates/ValueRefType.cs` | Enum |
| `Authorization/Abac/Templates/ConditionOperator.cs` | Enum |
| `Authorization/Abac/Templates/ConditionValueRef.cs` | Right-hand value descriptor |
| `Authorization/Abac/Templates/ConditionTemplate.cs` | Named reusable condition blueprint |
| `Authorization/Abac/Policies/AbacCondition.cs` | Template + runtime params |
| `Authorization/Abac/Policies/AbacPolicy.cs` | List of conditions for a resource+action |
| `Authorization/Abac/Policies/ResolvedCondition.cs` | Serializable; goes into OPA input |
| `Authorization/Abac/Registry/IAbacTemplateRegistry.cs` | Interface |
| `Authorization/Abac/Registry/AbacTemplateRegistry.cs` | In-memory thread-safe impl |
| `Authorization/Abac/Registry/BuiltInTemplates.cs` | SameDepartment, CreatedByMe, SameTenant |
| `Authorization/Abac/Engine/IAbacPolicyEngine.cs` | Interface |
| `Authorization/Abac/Engine/AbacPolicyEngine.cs` | Resolves conditions |
| `policies/authz/common/abac_eval.rego` | Generic Rego evaluator |
| `policies/tests/common/abac_eval_test.rego` | Policy tests |

### Files to Modify

| File | Change |
|------|--------|
| `Authorization/Models/OpaAuthorizationEnvelope.cs` | Add optional `Conditions` field |
| `Authorization/Abstractions/IResourceAuthorizationService.cs` | Add `AuthorizeWithPolicyAsync` overload |
| `Authorization/ResourceAuthorizationService.cs` | Implement new overload; inject `IAbacPolicyEngine` |

---

## Implementation Order

1. Enums and value types (Step 1)
2. `ConditionTemplate` (Step 2)
3. `AbacCondition`, `AbacPolicy`, `ResolvedCondition` (Step 3)
4. `IAbacTemplateRegistry` + `AbacTemplateRegistry` + `BuiltInTemplates` (Step 4)
5. `AbacPolicyEngine` (Step 5)
6. `OpaAuthorizationEnvelope` extension (Step 6)
7. `IResourceAuthorizationService` + `ResourceAuthorizationService` (Step 7)
8. `abac_eval.rego` generic policy (Step 8)
9. `abac_eval_test.rego` tests (Step 9)
10. DI registration (Step 10)

---

## Out of Scope (this plan)

- Migrating existing `GetUserProfileQueryHandler` from `AuthorizeAsync` to `AuthorizeWithPolicyAsync`
- Deleting `read-user.rego` or `manage-role.rego`
- Combining RBAC gate with the new overload (caller uses both overloads in sequence if needed)
- Caching resolved conditions
- Frontend changes

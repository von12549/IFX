# Fund Registry Architecture Review (Issues & Recommendations)

## Context
This document summarizes key architectural issues and recommendations identified during the review of the updated Fund Registry design (CRM / Registry / Holdings / Transaction).

The current design is already **production-grade and structurally sound**, with major improvements implemented:
- Account-centric Holdings and Transactions
- Multi-role Party model
- Proper module isolation via abstractions

The following sections focus only on **remaining risks, future scalability concerns, and recommended refinements**.

---

# 1. Investor Entity is Overloaded (Future Scalability Risk)

## Issue
The current `Investor` entity aggregates multiple concerns:
- KYC / AML
- Tax information
- Legal structure extensions
- Status / lifecycle

This makes `Investor` a **composite business object**, rather than a focused domain concept.

## Why This Becomes a Problem
In real-world fund systems:
- Non-investors (e.g., trustees, directors, beneficial owners) also require KYC
- Party lifecycle and Investor lifecycle are not identical
- KYC is a cross-cutting concern, not limited to investors

## Recommendation (Future Evolution)
Refactor toward a profile-based model:

```
Party
 ├── KycProfile
 ├── RiskProfile
 ├── TaxProfile
 ├── InvestorProfile (lightweight)
```

## Practical Guidance (Short-Term)
- Keep current design (acceptable)
- Avoid exposing `InvestorId` across modules
- Prefer `PartyId` as the canonical identity

---

# 2. API Layer Still Investor-Centric (Mismatch with Domain Model)

## Issue
Although Holdings are now account-based, APIs still expose investor-based access:

```
GET /api/v1/investor/{id}/holdings
```

## Problem
This introduces:
- Indirect query chains (Investor → Party → Account → Holdings)
- Increased complexity and performance overhead
- Conceptual inconsistency (domain is account-centric, API is investor-centric)

## Recommendation
Promote account-centric APIs as primary:

```
GET /api/v1/investment-account/{id}/holdings   ← primary
```

Retain investor-based APIs as derived queries:

```
GET /api/v1/investor/{id}/holdings   ← secondary (aggregated)
```

---

# 3. UserPartyLink is Too Restrictive (1:1 Constraint)

## Issue
Current constraints:

```
UNIQUE(TenantId, PartyId)
```

This enforces one user per party.

## Problem
Real-world scenarios require:
- Multiple users per organization (e.g., advisory firm)
- Multiple logins per legal entity
- Delegated access and shared operations

## Recommendation
Relax constraint:

```
REMOVE UNIQUE(TenantId, PartyId)
```

Retain:

```
UNIQUE(TenantId, UserId)
```

This enables a **many-to-one (User → Party)** relationship.

---

# 4. PartyRelationship Lacks Directional Semantics

## Issue
Current structure:

```
FromPartyId → ToPartyId
RelationshipType
```

Direction is implied but not explicitly enforced.

## Problem
This creates ambiguity in:
- Hierarchical relationships (e.g., ParentFirm)
- Graph traversal logic (especially in ABAC)
- Query interpretation

## Recommendation
Introduce explicit semantics:

Option A (Preferred):
- Define directional meaning per relationship type

Option B:
- Rename relationships to encode direction:
  - Parent → Child
  - Advisor → Client

This reduces ambiguity and prevents logic errors.

---

# 5. Advisor Authorization Model May Become Fragmented

## Current Design
Two-layer model:

1. PartyRelationship → "can advise investor"
2. AdvisorInvestmentAccountLink → "can manage account"

## Risk
As the system evolves, this may lead to:
- Scattered authorization logic
- Difficulty supporting complex delegation
- Redundant or overlapping rules

## Recommendation (Future Evolution)
Introduce a unified authorization abstraction:

```
AccessGrant
├── SubjectPartyId
├── ResourceType (Investor / Account)
├── ResourceId
├── Scope (Advise / Trade / View)
```

Benefits:
- Unified authorization model
- Easier extension (temporary access, delegation, cross-tenant scenarios)
- Cleaner ABAC integration

---

# 6. Missing Uniqueness Constraint in Holdings

## Issue
No explicit constraint preventing duplicate holdings per account/class.

## Risk
Data anomalies such as:
- Multiple rows for same (Account, Class)
- Incorrect aggregation of units

## Recommendation
Add constraint:

```
UNIQUE(TenantId, InvestmentAccountId, ClassId)
```

---

# 7. Future Improvement: Event & Ledger Separation

## Current State
Holdings represent current state only.

## Recommendation
Introduce separation:

```
Position (current state)
Ledger (event history)
```

Benefits:
- Auditability
- Replay capability
- Alignment with event sourcing patterns

---

# 8. Strategic Summary

## Strengths (Already Achieved)
- Correct account-centric domain model
- Strong module boundaries (DDD-compliant)
- Proper Party identity abstraction
- Event-driven holdings updates
- Multi-role Party support

## Remaining Improvements

### High Priority
1. Align APIs with account-centric model
2. Relax UserPartyLink constraints
3. Add holdings uniqueness constraint

### Medium Priority
4. Clarify PartyRelationship direction
5. Prepare for Investor decomposition

### Long-Term Evolution
6. Introduce AccessGrant model
7. Separate KYC / Risk / Tax profiles
8. Introduce ledger-based architecture

---

## Final Assessment

The system has evolved from a **conceptually correct design** to a **production-ready architecture** capable of supporting real-world fund administration scenarios.

Remaining work is focused on:
- Reducing conceptual mismatches
- Improving extensibility
- Preparing for scale and regulatory complexity

No fundamental redesign is required.


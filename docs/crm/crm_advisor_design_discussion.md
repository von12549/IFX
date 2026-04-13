# CRM Advisor Design Discussion

> **Status:** Open — pending business requirement clarification
> **Date:** 2026-04-12
> **Context:** Comparison of ChatGPT CRM design proposal vs current IFX implementation, focused on Advisor business

---

## Background

The ChatGPT CRM design (`/docs/crm_design_summary.txt`) proposes a generic `PartyRelationship(FromPartyId, ToPartyId, RelationshipType)` model. The current IFX implementation uses `PartyInvestorRelationship(PartyId, InvestorId, RelationshipType)` — a narrower, Investor-centric model.

This document records the analysis of how to handle the **Advisor business** without introducing Party-to-Party relationships.

---

## Current Model (as of 2026-04-12)

```csharp
// PartyType.cs
public enum PartyType
{
    FundManager = 1, Distributor = 2, Custodian = 3, TransferAgent = 4, Other = 5
}
// ⚠️  No Advisor

// RelationshipType.cs
public enum RelationshipType
{
    NomineeShareholder = 1, BeneficialOwner = 2, Distributor = 3, Custodian = 4
}
// ⚠️  No Advisor

// PartyInvestorRelationship.cs — links Party → Investor with RelationshipType + EffectiveDate + ExpiryDate
```

---

## Key Insight: Two Advisor Concepts Must Be Separated

| Concept | What it is | Where it belongs |
|---|---|---|
| **Advisor Firm** | A licensed IFA company or financial planning firm — a legal entity | CRM as a `Party` |
| **Individual Advisor (Rep)** | A person at the firm managing client relationships | Auth module as a `User` |

Fund registry transactions only need the **Advisor Firm** for commission calculation, AUM reporting, and regulatory disclosure. The individual rep is an internal concern of the firm.

This separation means **Party-to-Party relationships are not required** for the core fund registry use case.

---

## Proposed Solution: Two Enum Additions + EF Migration

### Step 1 — Add `Advisor` to `PartyType`

```csharp
public enum PartyType
{
    FundManager = 1, Distributor = 2, Custodian = 3, TransferAgent = 4,
    Advisor = 5,   // ← new
    Other = 6      // ← shifted
}
```

An Advisor firm is just a Party. Create `Party(Type=Advisor, Name="XYZ Wealth Mgmt")`.

### Step 2 — Add `Advisor` to `RelationshipType`

```csharp
public enum RelationshipType
{
    NomineeShareholder = 1, BeneficialOwner = 2, Distributor = 3, Custodian = 4,
    Advisor = 5    // ← new
}
```

Record `PartyInvestorRelationship(PartyId=<advisor firm>, InvestorId=<investor>, Type=Advisor, EffectiveDate=...)`.

---

## What This Design Supports

| Scenario | Supported? |
|---|---|
| Link Advisor firm to multiple Investors | ✅ One Party → many PartyInvestorRelationships |
| One Investor has multiple Advisors | ✅ Multiple rows, same InvestorId, Type=Advisor |
| Advisor relationship with start/end date | ✅ `EffectiveDate` + `ExpiryDate` already on entity |
| Get all Investors for an Advisor firm | ✅ `GetInvestorsByPartyQuery` already exists |
| Transfer of advisory (change advisor) | ✅ Expire old row, create new row |
| Track which Advisor is on a transaction | ✅ Read from `PartyInvestorRelationship` at time of transaction |
| Commission calculation by AUM | ✅ Query Holdings by InvestorId, join to Advisor relationship |

## What This Design Cannot Do

| Scenario | Supported? |
|---|---|
| Advisor firm has sub-advisors or branch offices | ❌ Requires Party-to-Party |
| Individual rep tracked as a Party | ❌ A person is not a legal entity — model as a User |
| Advisor manages another Advisor's book of business | ❌ Requires Party-to-Party |

---

## Migration Path if Party-to-Party Is Needed Later

Introduce a new table alongside the existing one — do not replace it:

```
PartyRelationship(FromPartyId, ToPartyId, RelationshipType, TenantId, EffectiveDate, ExpiryDate)
```

`PartyInvestorRelationship` stays unchanged. The two tables serve different purposes:
- `PartyInvestorRelationship` — Party's role in relation to an Investor (Advisor, Distributor, Custodian, NomineeShareholder, BeneficialOwner)
- `PartyRelationship` — Party-to-Party structural relationships (sub-advisory, firm hierarchy)

---

## Open Question — Requires Business Clarification

> **Is the Advisor scope single-tier or multi-tier?**
>
> - **Single-tier** (Advisor firm → Investor directly): Two enum additions are sufficient. Safe to implement now.
> - **Multi-tier** (firm → sub-firm → individual rep → Investor, white-labelling, sub-advisory networks): Party-to-Party table is required. Plan and implement before production data exists — retrofitting is a schema migration.

**Recommendation:** Confirm this requirement before implementing. The enum-only approach is a small, reversible change. The Party-to-Party table is a schema decision with long-term implications.

---

## Related Files

- `/docs/crm_design_summary.txt` — Original ChatGPT CRM design proposal
- `/.claude/Plans/20260401-fund-registry-crm-registry-holdings-transaction.md` — Current implementation plan
- `src/Modules/CRM/IFX.Modules.CRM.Domain/Enums/PartyType.cs`
- `src/Modules/CRM/IFX.Modules.CRM.Domain/Enums/RelationshipType.cs`
- `src/Modules/CRM/IFX.Modules.CRM.Domain/Entities/PartyInvestorRelationship.cs`

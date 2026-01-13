# README.md Maintenance & Splitting Playbook (Authoritative)

## Purpose
This document defines the mandatory structure and maintenance rules for README.md
and its related documentation.

Whenever the user requests:
- “Update README.md”
- “Modify README”
- “Add documentation”
- “Improve project documentation”

Claude MUST follow this playbook.

---

## Core Principles
1) README.md is a landing page, not a knowledge base.
2) README.md must remain concise and readable within 10 minutes.
3) All detailed explanations MUST be moved to /docs/.
4) README.md must NEVER contain enforceable rules or AI instructions.
5) README.md must NEVER duplicate content from /.claude/.

---

## Canonical Documentation Structure
```
.
├─ README.md
│
├─ docs/
│   ├─ overview.md
│   ├─ architecture/
│   │   ├─ index.md
│   │   ├─ modular-monolith.md
│   │   ├─ ddd.md
│   │   └─ cqrs.md
│   ├─ development/
│   │   ├─ getting-started.md
│   │   ├─ local-setup.md
│   │   ├─ configuration.md
│   │   └─ troubleshooting.md
│   ├─ deployment/
│   │   ├─ docker.md
│   │   ├─ database.md
│   │   └─ cloud.md
│   ├─ bioinformatics/
│   │   ├─ pipeline.md
│   │   ├─ preprocessing.md
│   │   ├─ analysis.md
│   │   └─ visualization.md
│   ├─ conventions/
│   │   ├─ naming.md
│   │   ├─ logging.md
│   │   └─ error-handling.md
│   └─ faq.md
```
This structure is the default and must be preserved across updates.
---

## README Allowed Content (Strict)
README.md MAY contain ONLY:
- Project name and one-paragraph description
- Key features (bullet points)
- High-level architecture summary (no deep dives)
- Quick Start (happy path only)
- Documentation index (links to /docs)
- Contributing (brief)
- License

README.md MUST NOT contain:
- Detailed architecture explanations
- Business rules
- Algorithm or pipeline details
- Large code blocks
- Enforcement language (e.g., “must”, “forbidden”) beyond basic usage

---

## Update Rules (Mandatory)
When executing “Update README.md”:

1) Classify each requested change into one of:
- Landing-level summary → README.md
- Explanatory detail → /docs/
- Rules / constraints → DO NOT ADD (belongs in /.claude/)
If a change does not belong in README.md, create or update the appropriate file under /docs/.

2) Enforce README Size & Scope
- If README.md grows beyond ~200–300 lines:
    - Move detailed sections into /docs/
    - Replace them with links
- Do not duplicate content between README and docs.

3) Preserve Stable Structure
- Section order in README.md must remain stable unless explicitly requested.
- New sections must be justified and minimal.
- Prefer adding links over adding text.

4) Keep docs/ Human-Readable
Documents under /docs/:
- Are written for humans, not AI
- Explain “what” and “why”
- Do not enforce behavior
- Do not reference .claude/

---

## Conflict Resolution
If:
- README content conflicts with /.claude/ → .claude/ wins
- User asks to put rules into README → explain and redirect to .claude/
- Scope is ambiguous → choose the narrower document (docs over README)

---

## Required Output
After updating README.md, Claude MUST:
1) Update or create necessary files under /docs/
2) Keep README.md concise
3) Briefly summarize:
    - What changed in README.md
    - Which docs were added or updated
Do NOT explain the playbook unless asked.

End of playbook.

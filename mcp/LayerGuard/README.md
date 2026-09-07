# LayerGuard

A Clean Architecture check for .NET, exposed over the Model Context Protocol so a language
model can call it instead of reading project files and source files itself.

**Every rule it applies is data in a file a person wrote.** There is no rule baked into the
code except the default direction of the four layers, and even that is overridable. A codebase states
its own project roles, ownership patterns, allowed directions, which packages a role may hold, which
projects a layer may never name, and where a kind of type has to be declared — and gets the
same answer every time it asks.

It parses; it does not compile. That means it answers on a codebase that does not build, needs
no restore, and does not care whether the SDK for the target framework is installed. What that
costs is written into every report.

A rule family the rule file is silent about **does not run, and the report says so by name.**
That is the difference between "checked and clean" and "never looked", and a reader who cannot
tell them apart has been misled by a green result.

Analysis reads only. The optional `snapshot` command and `check --report` write the explicitly
named evidence file; LayerGuard never edits product source or project files.

## IFX 03-A0 bootstrap

Version `0.3.0-a0` adds configurable `Contracts`, `IntegrationAdapter`, `Composition`,
`RuntimeHost`, and `Test` roles while preserving the four built-in roles for configurations that
do not opt in. IFX's bootstrap policy additionally checks module ownership and own/foreign
references; standalone and namespace-confined embedded adapters; provisional provider and
Contracts cycles; declaration placement; forbidden framework symbols and reflection strings;
event payload types; and BCL-only context/envelope type allowlists.

Migration baselines use exact fingerprints, require owner/reason/dates/removal criteria, reject
expired or stale entries, and fail on new findings. `*.Abstractions` is recognized as the
migration form of `Contracts`, while a separate rule forbids adding another legacy project.
Gate-owned catalogs and final allowlists are intentionally deferred to 03-A1.

---

## What it checks

The built-in default has four layers. A repository policy may add the A0 roles above and replace
the dependency matrix completely.

| depends on →       | Domain  | Application | Presentation | Infrastructure |
| ------------------ | ------- | ----------- | ------------ | -------------- |
| **Domain**         | —       | **refused** | **refused**  | **refused**    |
| **Application**    | allowed | —           | **refused**  | **refused**    |
| **Presentation**   | allowed | allowed     | —            | **refused**    |
| **Infrastructure** | allowed | allowed     | **refused**  | —              |

Twelve cells, five allowed, seven refused. That table is the whole rule. Presentation and
Infrastructure are siblings on the outside and never see each other; Domain sees nobody.

A project is assigned to a layer **by its name**. By default:

| layer          | project name matches |
| -------------- | -------------------- |
| Domain         | `*.Domain`           |
| Application    | `*.Application`      |
| Presentation   | `*.Presentation`     |
| Infrastructure | `*.Infrastructure`   |

**A project matching none of the configured patterns is outside the check.** Contract and wiring
projects are checked when the repository policy assigns them the corresponding A0 roles.

### Direct and transitive both count

.NET forwards project references. If `Domain` references `Shared`, and `Shared` references
`Infrastructure`, then **Domain can use Infrastructure types** even though `Domain.csproj`
names no such thing. The boundary is gone whether or not anyone has walked through it yet.

So a violation is reported in two shapes:

- **direct** — the project names the other one in its own file. Fix it where it is written.
- **transitive** — a project it references passes the other one along. `Domain.csproj` has
  nothing to change; the fix is at the hop that carries it.

Every transitive violation therefore reports **the whole chain** plus the exact line to edit:

```
V002 — Sample.Domain sees Sample.Infrastructure
  Direction   Domain must not depend on Infrastructure
  Reached     transitive
  Path        Sample.Domain → Sample.Shared → Sample.Infrastructure
  Read at     .../Sample.Domain/Sample.Domain.csproj:8
  Fix at      .../Sample.Shared/Sample.Shared.csproj:8
  How         Sample.Domain does not name Sample.Infrastructure itself. Close the last hop:
              add PrivateAssets="all" to Sample.Shared's reference to Sample.Infrastructure,
              or split Sample.Shared so it no longer carries it.
```

Without the chain, someone opens `Domain.csproj`, finds nothing to fix, and concludes the tool
is wrong.

### Two ways a reference stops travelling

Both are honoured, and both are read from the project file:

- `PrivateAssets="all"` (or `compile`) on a reference — that reference stays inside the project
  that declares it. Written as an attribute **or as a child element**; the child form is what a
  naive attribute reader misses.
- `<DisableTransitiveProjectReferences>true</DisableTransitiveProjectReferences>` on a project —
  that project sees only what it names itself.

### The table is applied twice

A reference says a layer **can** see another one. An import says a file **does**. `check` reads
the `using` directives out of every source file and applies the same table above to those too.

The two answer different questions and neither replaces the other. A reference nothing imports is
a boundary already lost; an import is where somebody walked through it.

It parses the C# rather than searching it, which is not a detail:

| written in the file                    | a text search calls it | `check` calls it         |
| -------------------------------------- | ---------------------- | ------------------------ |
| `using var scope = Get();`             | an import              | a statement, ignored     |
| `// using X.Infrastructure;`           | an import              | a comment, ignored       |
| `"X.Infrastructure.Thing"` in a string | a reference            | checked when `forbiddenText` states a pattern |
| `using Repo = X.Infrastructure.R;`     | missed by `^using X`   | an alias import, read    |
| a `using` inside `#if DEBUG`           | an import              | read, and marked as such |

That last row is the one worth knowing about. A branch the preprocessor turned off never reaches
the syntax tree at all, so a tool that walks only the tree reports nothing **and says nothing** —
a silent miss, which is worse than a text search that at least sees the characters. Those regions
are parsed on their own and reported with a `kind` of
`import in a branch the preprocessor had turned off`, because the import is real in whatever
configuration turns that branch on.

Namespaces are matched against the names of the projects the run loaded: `using X.Auth.Domain.Users`
belongs to the project `X.Auth.Domain`. A namespace belonging to a project that matches no layer
is left alone, the same way its references are — outside the check means outside all of it, not
outside one rule and inside another. A namespace no loaded project declares is left alone — it
comes from a package or from code outside the scope, and the direction table has nothing to say
about either. Nothing is resolved by a compiler, so **the code does not have to build**; a file
that does not even parse still gives up its import lines.

### The rules that are not about direction

The direction table is one family. Ownership, provider graph, source-symbol, declaration,
payload and baseline families catch facts the table structurally cannot see; each is silent
until the rule file states it.

| family                              | catches                                                       | why the direction table cannot                                           |
| ----------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **packages a ring may hold**        | `using Microsoft.EntityFrameworkCore` in a Domain entity      | a package carries no ring, so no pair of rings is ever refused           |
| **packages a ring may never hold**  | a database library in Presentation                            | an allow-list would have to name every package the ring may keep         |
| **projects a ring may never name**  | Domain referencing its own module's `.Abstractions`           | a project matching no layer is Outside, and Outside is never ruled on    |
| **projects a ring may name at all** | Domain reaching for a shared project nobody sanctioned        | the table refuses directions, and cannot say "only these, nothing else"  |
| **where a type must be declared**   | a command handler sitting in Presentation                     | nothing points the wrong way; the type is simply in the wrong project    |
| **what a type answers to**          | a repository class whose interface never left Infrastructure  | the class is in the right project and imports nothing wrong              |
| **what a type is handed**           | an endpoint holding a repository instead of asking a use case | the endpoint may legitimately see that layer; holding one is the mistake |
| **every ring present per module**   | a module that quietly lost its Domain project                 | a layer that is absent has no dependencies to refuse                     |

**Packages** are read twice: from what a project declares, and from imported namespaces that
no project the run loaded declares. The second reading is what catches a package that arrived
through another project and was never declared where it is used — but a namespace is not a
package id, so that reading matches a name rather than resolving a fact.

**Forbidden packages** are the deny half of the same reading, and they exist because the two
lists answer different questions. An allow-list says what a ring is built from, which is worth
stating for a ring that should hold almost nothing. A deny-list says what a ring must never
reach for, which is the only way to rule on one kind of package inside a ring that legitimately
holds dozens. The deny-list is read first, so a package both lists name is reported once, under
the rule that names it rather than the rule that merely fails to allow it.

**Allowed projects** are the same reading turned around. A deny-list needs somebody to have
foreseen the wrong project; an allow-list refuses everything nobody sanctioned, which is what a
rule like "Domain's only outside reference is the shared domain project" actually says. Where a
reference is both off the allow-list and a direction the table refuses, the table reports it and
the allow-list stays quiet, so one mistake stays one finding.

**Forbidden projects** are matched on the reference a project writes in its own file, not on
what it can reach. A rule about who may _name_ a project is not a rule about who can reach it,
and conflating the two would report the same edge twice under different rules.

**Constructor parameters** are a third reading of the same boundary, and the narrowest. A
reference says a layer _can_ see something; an import says a file _names_ it; a parameter says an
instance was handed over and kept. An endpoint is allowed to see Domain, so nothing about a
reference or an import is wrong when it takes a repository — only the constructor shows it. Every
name written inside the parameter's type is matched, so a list of them or a nullable one is
still one. What the method body does with it is not read.

A parameter can be refused two ways, and they answer different questions. A **pattern** refuses a
name — `I*Repository` says what a repository is called, which is a convention the codebase
states out loud. A **layer** refuses an origin — "never a concrete class from Infrastructure"
names no convention at all, because a concrete class is not called anything in particular. That
second form reads the same declaration index the contract rule uses, and where the layer being
judged declares a type of the same name itself, the name binds at home and nothing is reported.

**Contracts** are the one rule that has to look outside the file in front of it. Whether the
interface a class names was declared in Domain cannot be read off the class, so every source
file is read once to build an index of which layer declares which name — and only when a rule
asks for it. The index is keyed on the simple name, so `Acme.Sales.IOrderRepository<Order>` in a
base list and `IOrderRepository<T>` in Domain are the same contract; two types sharing a simple
name in different layers both land under it, and a rule they both match passes on either.

**Declaration rules** match on the type's own name, because a naming convention is the only
thing a codebase states out loud about what a type is for. A handler is a handler because
somebody called it one. Which names mean what belongs in the rule file, never in the tool.

### What is not checked

Every report names its own limits under `notChecked`, so a clean result is never mistaken for a
complete one. Two kinds appear there.

**Rules nobody wrote.** A family the rule file is silent about is named individually — "which
packages a ring may hold — the rule file names none, so no package was judged". Silence is not
consent, and a green verdict on an empty rule file means almost nothing.

**Limits of parsing without compiling.** These are permanent:

- type names written out in full in code, with no import line
- which project a name really binds to — namespaces are matched against project names, not
  resolved by a compiler
- method bodies, and any use of a type that needs no import
- anything inside a project that matches no layer

Method bodies are the sharpest of these. A rule about what a method _hands back_ is only worth
having where the return type says it: an endpoint declared `Task<ActionResult<Investor>>` names
the entity, one declared `Task<IResult>` that calls `Results.Ok(investor)` does not, and no
amount of parsing tells the two apart. Where a codebase writes the second shape, that rule reads
clean without looking, and a rule that cannot fail is worse than no rule. Leave it to a reader.

The first two are the price of not needing the code to build. `LIMITS.md` sets out each of them,
what it costs, and what would move the line — including why a rule about what a method returns
is worth having only where the return type names the thing, and why a Roslyn analyzer in the
build is complementary to this tool rather than a replacement for it.

---

## Using it

### As an MCP server

Run with no arguments and it speaks MCP over stdin/stdout.

In this repository that registration already exists — `.mcp.json` at the repository root:

```json
{
  "mcpServers": {
    "layerguard": {
      "command": "dotnet",
      "args": [
        "run",
        "--project",
        "mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj",
        "--verbosity",
        "quiet",
        "--nologo"
      ]
    }
  }
}
```

Two details that are not decoration. `--verbosity quiet --nologo` silences the build, which
otherwise writes to the same stream the protocol uses and the client sees a line it cannot
parse. And the project path is relative, so start the client from the repository root or
`dotnet run` will not find the project.

The first launch builds, which takes a few seconds; later ones start immediately. To take that
cost off the client entirely, install it once and call the binary:

```bash
dotnet pack mcp/LayerGuard/src/LayerGuard
dotnet tool install --global --add-source ./nupkg layerguard
```

```json
{
  "mcpServers": {
    "layerguard": { "command": "layerguard", "args": [] }
  }
}
```

### Commands and MCP tools

The split between them is the point. `check` judges, and every rule it applies came from a file
a person wrote and can be shown. `scan` only lists, so a question no rule covers can still be
answered without inventing a rule at run time. `describe_rules` says what `check` would apply,
so a verdict can be read back to the rule that produced it.

| tool             | what it does                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `check`          | Applies every rule the rule file states, and returns each finding with the file and line to open. Takes one `path` — a `.csproj`, a folder, or a `.sln` — plus optional `configPath` and `format`. **Answers in JSON by default**: the caller acts on `fixAt.file` and `fixAt.line`, and those are fields, not prose to parse. Also returns `checked` — the rule families that ran — and `notChecked`, which names the ones the rule file left silent. |
| `scan`           | Lists what is in the codebase with no verdict attached. `select` picks `projects`, `packages`, `imports` or `declarations`; `ring`, `module` and `namePattern` narrow the result. Use it for a question the rule file does not cover, instead of reading the source.                                                                                                                                                                                   |
| `describe_rules` | The rules that would be applied: name patterns, the direction table, package allow-lists, forbidden projects, declaration placement, and what nothing here looks at. Call it before `check` when the rules matter to the answer.                                                                                                                                                                                                                       |

The CLI also provides `snapshot`, which creates a reviewed migration baseline. It is not exposed
as an MCP analysis tool because it changes the accepted-debt state.

`path` decides the scope for both `check` and `scan`:

- a **`.csproj`** — that project is checked; other projects are loaded only to resolve what its
  references point at
- a **folder** — every `.csproj` beneath it is checked
- a **`.sln`** — every project the solution lists is checked

#### What `scan` returns

| `select`                       | one row per        | carries                                                                                                                                                    |
| ------------------------------ | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `projects`                     | project            | ring, module, file, how many references and packages it declares                                                                                           |
| `packages`                     | `PackageReference` | id, version, the project and ring holding it, file and line                                                                                                |
| `imports`                      | `using` directive  | the namespace, the project and ring it belongs to (or `outside` / `framework`), file and line, and whether it sits in a branch the preprocessor turned off |
| `declarations[].mustImplement` | not asked          | the type must name a base type some project in that ring declares; a type with no base list never satisfies it                                             |
| `declarations`                 | type declaration   | kind, name, base types, the project and ring it is declared in, file and line                                                                              |

### From the command line

The same answers, without an MCP client:

```bash
layerguard check src/Modules                     # every rule the rule file states
layerguard check src/Modules --format json
layerguard check src --baseline mcp/LayerGuard/baselines/b0.5.json --report artifacts/layerguard.json
layerguard snapshot src --output baseline.json --owner architecture-team --expires 2026-12-31
layerguard scan  src/Modules --select packages   # facts, no verdicts
layerguard scan  src/Modules --select declarations --ring Application --name "*Handler"
layerguard rules                                 # the rules in force
```

`check` exits `0` when clean. With a baseline it exits `0` only when every finding is historical
and every baseline entry still matches. New findings or stale entries exit `1`; invalid or
expired baseline/configuration data exits `2`.

---

## Writing the rules

Put a `layerguard.json` anywhere at or above the path being checked; the nearest one wins, the
same way MSBuild finds its own files. Pass `--config` (or `configPath`) to name one directly.

Every key is optional. **An absent key is not a permissive rule — it is no rule**, and the
report says so under `notChecked` rather than passing quietly.

```json
{
  "rings": {
    "Domain": ["*.Domain", "*.Core"],
    "Application": ["*.Application", "*.UseCases"],
    "Presentation": ["*.Presentation", "*.Api", "*.Web"],
    "Infrastructure": ["*.Infrastructure", "*.Persistence"]
  },

  "allowedDependencies": {
    "Domain": [],
    "Application": ["Domain"],
    "Presentation": ["Application"],
    "Infrastructure": ["Application", "Domain"]
  },

  "allowedReferences": {
    "Domain": ["Acme.Shared.Domain"]
  },

  "allowedPackages": {
    "Domain": [],
    "Application": [
      "MediatR*",
      "FluentValidation*",
      "AutoMapper*",
      "Microsoft.Extensions.*.Abstractions"
    ]
  },

  "forbiddenDependencies": {
    "Presentation": ["I*Repository"]
  },

  "forbiddenDependencyOrigins": {
    "Application": ["Infrastructure"]
  },

  "forbiddenPackages": {
    "Presentation": ["Microsoft.EntityFrameworkCore*", "Dapper*", "Npgsql*"]
  },

  "forbiddenReferences": {
    "sameModule": ["*.Abstractions"],
    "byRing": {
      "Domain": ["*.Legacy*"]
    }
  },

  "declarations": [
    { "match": "I*Repository", "mustLiveIn": "Domain" },
    { "match": "*CommandHandler", "mustLiveIn": "Application" },
    {
      "match": "*Repository",
      "kind": "class",
      "mustLiveIn": "Infrastructure",
      "mustImplement": "Domain"
    },
    { "match": "*Validator", "mustLiveIn": "Application", "severity": "bends" }
  ],

  "ruleRefs": [
    {
      "ref": "D-1",
      "text": "Domain references no other project of its own module.",
      "rules": ["RING-DIRECTION", "RING-REFERENCE"],
      "ring": "Domain",
      "sameModule": true
    },
    {
      "ref": "C-8",
      "text": "An endpoint returns its own response type.",
      "rules": [],
      "notMeasured": "the whole rule"
    }
  ],

  "severities": {
    "RING-PACKAGE": "bends"
  },

  "requireRings": true
}
```

| key                              | absent means                                         | present means                                                                                                                                                                                                              |
| -------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rings`                          | the built-in `*.Domain` … patterns                   | these patterns instead                                                                                                                                                                                                     |
| `allowedDependencies`            | the built-in direction table                         | this table instead                                                                                                                                                                                                         |
| `ownership`                      | parent-folder fallback                               | project-name patterns with `{module}` and optional fail-closed ownership                                                                                                                                                    |
| `referenceScopes`                | allowed role pairs ignore ownership                  | narrows a role pair to `own`, `foreign`, `any`, or `none` ownership                                                                                                                                                          |
| `providerContracts`              | no provider edge is approved                         | provisional consumer-to-provider graph; 03-A1 replaces this with Gate 03 input                                                                                                                                              |
| `embeddedAdapterNamespaces`      | no embedded adapter namespace is approved            | only matching Infrastructure namespaces may use foreign Contracts                                                                                                                                                           |
| `forbiddenProjectNames`          | no project name is forbidden                         | reports migration-only or retired project patterns even when their role is recognized                                                                                                                                       |
| `allowedReferences`              | **no reference allow-list**                          | a ring listed here may name only projects matching, in its own project file; a ring absent from the list may name anything; an empty list allows no reference at all                                                       |
| `allowedPackages`                | **no package is judged**                             | a ring listed here may hold only what matches; a ring absent from the list is still unjudged; an empty list allows nothing at all                                                                                          |
| `forbiddenDependencies`          | not asked                                            | no type declared in that ring may take a constructor parameter whose type names a match; a ring absent from the list is unjudged                                                                                           |
| `forbiddenDependencyOrigins`     | not asked                                            | no type declared in that ring may take a constructor or method parameter whose type was declared in one of the named rings                                                                                                 |
| `forbiddenPackages`              | **no package is forbidden**                          | a ring listed here may never hold or import a package matching, whatever the allow-list says; a ring absent from the list is unjudged                                                                                      |
| `forbiddenReferences.sameModule` | no such rule                                         | no project may reference a project in its **own module** whose name matches                                                                                                                                                |
| `forbiddenReferences.byRing`     | no such rule                                         | a project in that ring may never reference a matching project, whatever module it is in                                                                                                                                    |
| `declarations`                   | **no placement is judged**                           | a type whose name matches must be declared in that ring; `severity` defaults to `breaks`                                                                                                                                   |
| `declarationNamespaces`          | no role/namespace declaration policy                 | names public Contracts, Ports, Events and Adapters and supports explicit exceptions                                                                                                                                         |
| `forbiddenDeclarations`          | no declaration responsibility is forbidden           | prevents implementation-shaped types such as handlers and DbContexts in Contracts                                                                                                                                           |
| `forbiddenNamespaces/Symbols/Text` | no source leak policy                              | checks imports, qualified/simple syntax names and configured reflection/configuration strings                                                                                                                               |
| `payloads`                       | no payload type policy                               | denies internal types or applies a default-deny primitive allowlist to matching declarations                                                                                                                                |
| `ruleRefs`                       | findings carry this tool's rule ids and nothing else | every finding also carries the numbered rule of your own rulebook it answers to, and the report gains a row per numbered rule: what settles it, how many findings came back, and what a clean result would still not prove |
| `severities`                     | every rule reports at the level it carries           | that rule id reports at the level named here; only `breaks`, `bends` and `drift` are accepted, and anything else is refused when the file is read                                                                          |
| `requireRings`                   | not asked                                            | every module must hold a project in each ring named under `rings`                                                                                                                                                          |

`*` is the only wildcard, and matching is case-insensitive.

`Presentation → Domain` and `Infrastructure → Domain` are the two direction cells people
disagree about. Both are allowed by default. Drop `"Domain"` from `Presentation` and an endpoint
touching an entity directly becomes a violation.

### The rulebook is a mapping, not a retelling

A rule id here says which check failed. A codebase's own rulebook says which numbered rule a
reader was promised an answer to, and the two are many-to-many: `RING-DIRECTION` serves four
rules that differ only by which ring the finding came from, and one of those rules is settled by
four different checks at once. Anyone holding a report and a rulebook can work the mapping out —
and will work it out differently each time, silently, with no way to tell that two reports of
the same codebase answered different questions.

`ruleRefs` states it once. Every finding then carries its `ref`, and the report gains one row per
numbered rule: what settles it, how many findings came back under it, and — the row that matters
— what a clean result would still not prove. A rule nothing settles has an empty `rules` list and
appears anyway, because a rule missing from that table is indistinguishable from a rule that
passed.

First match wins, so a narrow entry is written above the one it carves out of. A rulebook naming
a check this tool does not emit is refused when the file is read: left through, it would match
nothing for ever, and its rule would read as measured by something that never runs.

Severities are part of the rules, not decoration. A rulebook that calls one rule a break and
another a bend is saying which finding to open first, and reporting them all at one level throws
that claim away. `severities` is keyed on the rule ids the report already carries, so a level can
be traced back to the line that set it — and a level nobody recognises is refused when the file
is read, rather than producing findings every reader filtering on the three known levels quietly
drops.

Every report names the rule source it used, so a surprising verdict can be traced to the file
that produced it — and a missing verdict to the rule nobody wrote.

### Module ownership

`ownership.modulePatterns` may contain one `{module}` token, for example
`IFX.Modules.{module}.*`. This is the preferred A0 source and avoids prefix ambiguity such as
`Billing` versus `BillingPlus`. When no pattern matches, the legacy fallback is the folder holding
the project folder. `ownership.requireKnown` turns unresolved in-scope ownership into a finding.

In a flat layout, where every project folder sits directly under one directory, that directory
becomes the single module every project shares. `requireRings` then asks for all four layers
once across the codebase, which is usually what a flat layout means, and `sameModule` applies
to every reference. If that is not the intent, use `forbiddenReferences.byRing` instead, which
does not consult the module at all.

---

## Building and testing

```bash
dotnet build   mcp/LayerGuard/src/LayerGuard
dotnet test    mcp/LayerGuard/tests/LayerGuard.Tests
pwsh -File scripts/Invoke-LayerGuard.ps1
```

Every case is a folder of real project files under `tests/fixtures`, named for the situation it
holds. Open the folder and the case is in front of you.

| fixture                      | holds                                                                                             | expected                                             |
| ---------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `DirectReference`            | six refused pairs, each written in the referencing project's own file                             | 6 direct findings                                    |
| `DirectSiblingReference`     | the seventh: Infrastructure naming Presentation                                                   | 1 direct finding                                     |
| `IndirectReference`          | the same six pairs, each reached through a carrier project                                        | 6 transitive findings                                |
| `IndirectSiblingReference`   | the seventh, reached through a carrier                                                            | 1 transitive finding                                 |
| `IndirectKeptPrivate`        | `IndirectReference` again, with every carrier marking its reference private                       | nothing                                              |
| `IndirectSharedHop`          | one carrier, two layers travelling through it                                                     | 2 findings, one line to fix                          |
| `DisableTransitive`          | one carrier, one layer that disabled transitive references and one that did not                   | 1 finding, from the layer without the property       |
| `PrivateAssetsAttributeForm` | the private marker written as an attribute, beside a carrier that declares nothing                | 1 finding, from the open carrier                     |
| `CustomRules`                | a codebase naming its layers Core, UseCases, Api, Persistence, with a `layerguard.json` beside it | 1 finding the built-in rules would allow             |
| `SolutionScope`              | three projects on disk, a solution listing two                                                    | 1 finding through the solution, 2 through the folder |
| `BootstrapArchitecture`      | A0 roles, ownership, adapters, context, payload, cycles, generated/test code and runtime host      | focused positive and negative A0 findings             |
| `AllowedDirections`          | the five dependencies Clean Architecture permits                                                  | nothing                                              |

The two sibling fixtures exist because Presentation and Infrastructure refuse each other in both
directions, and a single folder holding both would have the two projects referencing each other.

Four of these are built as contrasts rather than single cases, because a fixture that only ever
produces silence proves nothing on its own: `DisableTransitive` and `PrivateAssetsAttributeForm`
each put a stopped reference beside an identical one that was not stopped, `IndirectKeptPrivate`
is `IndirectReference` with the markers added and the tests compare the two shapes, and
`CustomRules` uses layer names the built-in rules reject outright, so a finding there can only
mean the config file was read.

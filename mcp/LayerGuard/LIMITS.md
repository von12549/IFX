# What this tool cannot see

Every check here reads syntax. Nothing is compiled, nothing is restored, and no name is resolved
to the thing it binds to. That is what lets it answer on a codebase that does not build, and it
is paid for in the four limits below.

They are permanent, they are the same for every codebase, and every report names them under
`notChecked` so a clean result is never mistaken for a complete one.

## Syntactic names are not semantic bindings

`using Acme.Data;` and a fully-qualified `Acme.Data.Context` are both visible syntax. A0 can match
either against configured forbidden patterns, but it cannot prove which assembly or symbol the
name binds to. Closing that gap requires a semantic model from a compilation.

## Which project a name really binds to

A namespace is matched against the names of the projects the run loaded, longest first. That is
a good guess and not a fact: two projects can declare the same namespace, and a namespace can
belong to a package nobody declared. Where a name matches a type the judging layer declares
itself, the rules read it as binding at home, because the reading that accuses nobody is the
safer one to be wrong about.

## What a method body does

Constructor and method parameters are read; bodies are not. So a dependency handed to a type is
visible and what the type then does with it is not.

This has a sharp consequence for any rule about what a method **returns**. Where the return type
names the thing — `Task<ActionResult<Order>>` — the rule works. Where the method returns a
wrapper it builds inside its own body — `Task<IResult>` closing over `Results.Ok(order)` — the
rule reads clean without looking, and no amount of parsing separates the two.

**A rule that cannot fail is worse than no rule**, because it fills the column. Where a codebase
is written the second way, state the rule as unmeasured rather than shipping a check that always
passes.

## What a naming convention does not cover

Rules about where a kind of type belongs match on the type's own name, because what a type is
for is something a codebase states out loud by naming it. A repository interface called
`IUserStore` is missed by a convention written as `I*Repository`.

That is a limit of the convention, not of the tool, and the rule file is where a codebase widens
it. It is the one limit here that costs nothing but words to move.

---

## Saying so is the point

A rule family the rule file does not state **does not run, and the report names it**. A numbered
rule the rule file declares but nothing settles appears in the report anyway, with an empty
`settledBy` list, because a rule missing from that table cannot be told from one that passed.

The distinction between "checked and clean" and "never looked" is the one a green result must
never blur. Every limit above is reported next to the findings rather than left for a reader to
know already.

## What would move the line

A **Roslyn analyzer in the build** closes the first two limits outright and makes the third
reachable, because a semantic model resolves a name to the thing it binds to. It cannot do any
of the project-level rules: an analyzer runs per compilation, cannot read a `.csproj`, cannot
separate a declared reference from one that arrived transitively, and never runs at all for a
project that is missing. The two tools cover opposite halves and neither replaces the other.

**`NsDepCop`** is the narrow version of the same idea, for namespace rules, without new code.

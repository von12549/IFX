# .ula — ULA's signpost in this project

ULA (Unattended Loop Agent) is a tool pointed at this project. It is **not part
of this project's codebase** — treat it as external tooling.

**ULA never commits.** It plans, drafts, gates and hands over; you decide what
enters git. After a run, `git log` is untouched.

## What is in here

Almost nothing, on purpose:

```
.ula/
├── README.md     this file (the only tracked entry)
└── .gitignore    keeps anything else here out of git
```

Run output does **not** land in this folder. Every run's stage directories, its
frozen playbook and its deliverables live in this project's store, outside this
repository.

## Where the state lives

```
C:\Users\junxi\.ula\projects/C--Cxisoftware-IFX-IFX
```

That separation is deliberate: worker sessions run with this repo as their
working directory, so state kept here would be readable by the worker and would
bias it. The `.gitignore` beside this file is the backstop — if anything ever
does land in `.ula/`, git still never sees it.

## Commands (run from the project root)

```bash
ula status     # what this project has running — read-only
ula serve      # the portal: projects, runs, gates, docs
```

## Do not

- Put project code here — this folder is ULA's, and is gitignored except README.
- Expect run output or engine state here — both are at the path above.

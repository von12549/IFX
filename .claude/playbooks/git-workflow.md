# Git Workflow Playbook

## Purpose
This document defines the git workflow that Claude must follow when making commits, creating branches, and managing pull requests in this repository.

---

## Golden Rules

1. **Never commit without explicit user request** - Ask before committing changes
2. **Never push without explicit user request** - Local commits are safe, pushing is not
3. **Never force push to main/master** - Warn and refuse unless explicitly overridden
4. **Never skip hooks** - No `--no-verify` or `--no-gpg-sign` unless explicitly requested
5. **Never amend commits you didn't create** - Always verify authorship first

---

## Branch Naming Convention

**Pattern:** `{type}/{scope}/{short-description}`

| Type | Purpose | Example |
|------|---------|---------|
| `feature/` | New functionality | `feature/auth/password-reset` |
| `fix/` | Bug fixes | `fix/api/null-reference-error` |
| `refactor/` | Code restructuring | `refactor/domain/user-entity` |
| `doc/` | Documentation changes | `doc/readme-update` |
| `test/` | Test additions/fixes | `test/integration/login-flow` |
| `chore/` | Maintenance tasks | `chore/deps/update-packages` |

**Rules:**
- Use lowercase with hyphens (kebab-case)
- Keep descriptions short (2-4 words)
- Include module scope when applicable (e.g., `auth`, `api`, `infra`)

---

## Commit Message Format

**Structure:**
```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Type prefixes:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `docs`: Documentation only
- `test`: Adding or correcting tests
- `chore`: Maintenance, dependencies, config
- `perf`: Performance improvement
- `style`: Formatting, whitespace (no code change)

**Examples:**
```
feat(auth): add password reset endpoint

fix(sso): resolve null reference in OIDC callback

refactor(domain): extract validation to value objects

docs(api): update endpoint documentation
```

**Rules:**
- Subject line: max 72 characters, imperative mood ("add" not "added")
- Body: explain "why" not "what" (the diff shows "what")
- Reference issues when applicable: `Fixes #123`

---

## Commit Workflow

When the user requests a commit, Claude MUST:

### Step 1: Gather Information (parallel)
```bash
git status                           # See untracked and modified files
git diff                             # See unstaged changes
git diff --staged                    # See staged changes
git log -5 --oneline                 # See recent commit style
```

### Step 2: Analyze and Draft
- Review all changes to be committed
- Check for sensitive files (.env, credentials, secrets)
- Draft a commit message following the format above

### Step 3: Stage and Commit
```bash
git add <files>                      # Stage relevant files
git commit -m "$(cat <<'EOF'
<commit message>

Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 4: Verify
```bash
git status                           # Confirm commit succeeded
```

---

## Pre-commit Hook Handling

If a commit fails due to pre-commit hooks:

1. **Review the hook output** - Understand what failed
2. **Fix the issues** - Address formatting, linting, or test failures
3. **Retry the commit** - Attempt once more
4. **If hooks modified files**, verify before amending:
   ```bash
   git log -1 --format='[%h] (%an <%ae>) %s'  # Verify it's YOUR commit
   git status                                   # Verify not pushed
   ```
5. **Only amend if both checks pass** - Otherwise create a new commit

---

## Pull Request Workflow

When the user requests a PR, Claude MUST:

### Step 1: Gather Context (parallel)
```bash
git status                           # Check working tree
git log main..HEAD --oneline         # All commits to include
git diff main...HEAD                 # Full diff from base
```

### Step 2: Prepare
- Ensure branch is pushed: `git push -u origin <branch>`
- Analyze ALL commits in the PR, not just the latest

### Step 3: Create PR
```bash
gh pr create --title "<type>(<scope>): <description>" --body "$(cat <<'EOF'
## Summary
- <bullet points describing changes>

## Test plan
- [ ] <testing checklist>

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 4: Report
- Return the PR URL to the user

---

## Prohibited Actions

**Never execute without explicit user request:**
- `git push --force` or `git push -f`
- `git reset --hard`
- `git rebase -i` (interactive rebase not supported)
- `git clean -fd`
- `git checkout -- .` (discards all changes)
- `git stash drop`
- Any command with `--no-verify`

**Always warn and confirm before:**
- Pushing to `main` or `master`
- Rebasing commits that may be shared
- Amending commits
- Deleting branches (local or remote)

---

## Safe Operations

These operations are safe and can be performed without additional confirmation:
- `git status`
- `git log`
- `git diff`
- `git branch` (listing)
- `git checkout -b <new-branch>` (creating new branch)
- `git add <files>` (staging)
- `git stash` (saving work)
- `git fetch`

---

## Conflict Resolution

When merge conflicts occur:

1. **Identify conflicts**: `git status`
2. **Read conflicting files**: Use Read tool to understand both sides
3. **Ask user for guidance** if intent is unclear
4. **Resolve using Edit tool** - Keep both sides' intent intact
5. **Mark resolved**: `git add <file>`
6. **Complete merge**: `git commit` (no message needed for merge commits)

---

## Common Scenarios

### Starting a new feature
```bash
git checkout main
git pull origin main
git checkout -b feature/scope/description
```

### Updating branch with main
```bash
git fetch origin main
git merge origin/main
# Resolve conflicts if any
```

### Discarding local changes (with user confirmation)
```bash
git checkout -- <file>        # Single file
git restore .                 # All files (Git 2.23+)
```

### Viewing history
```bash
git log --oneline -20                    # Recent commits
git log --oneline --graph --all          # Visual branch history
git log -p <file>                        # File history with diffs
```

---

## Configuration

Claude MUST NOT modify git configuration:
- No `git config` commands
- No changes to `.gitconfig`
- No changes to `.git/config`

If configuration changes are needed, inform the user and let them make the changes.

---

End of playbook.

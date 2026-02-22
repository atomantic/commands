---
description: Unified DevSecOps audit, remediation, PR, and Copilot review loop with worktree isolation
argument-hint: "[--scan-only] [--no-merge] [path filter or focus areas]"
---

# MakeGood — Unified DevSecOps Pipeline

Run the full DevSecOps lifecycle: audit the codebase with 7 deduplicated agents, consolidate findings, remediate in an isolated worktree, create a single PR with SemVer bump, run a Copilot review loop, and merge.

Parse `$ARGUMENTS` for:
- **`--scan-only`**: run Phase 0 + 1 + 2 only (audit and plan), skip remediation
- **`--no-merge`**: run through PR creation (Phase 5), skip Copilot review and merge
- **Path filter**: limit scanning scope to specific directories or files
- **Focus areas**: e.g., "security only", "DRY and bugs"

## Phase 0: Discovery & Setup

Detect the project environment before any scanning or remediation.

### 0a: VCS Host Detection
Run `gh auth status` to check GitHub CLI. If it fails, run `glab auth status` for GitLab.
- Set `VCS_HOST` to `github` or `gitlab`
- Set `CLI_TOOL` to `gh` or `glab`
- If neither is authenticated, warn the user and halt

### 0b: Project Type Detection
Check for project manifests to determine the tech stack:
- `package.json` → Node.js (check for `next`, `react`, `vue`, `express`, etc.)
- `Cargo.toml` → Rust
- `pyproject.toml` / `requirements.txt` → Python
- `go.mod` → Go
- `pom.xml` / `build.gradle` → Java/Kotlin
- `Gemfile` → Ruby
- `*.csproj` / `*.sln` → .NET

Record the detected stack as `PROJECT_TYPE` for agent context.

### 0c: Build & Test Command Detection
Derive build and test commands from the project type:
- Node.js: check `package.json` scripts for `build`, `test`, `typecheck`, `lint`
- Rust: `cargo build`, `cargo test`
- Python: `pytest`, `python -m pytest`
- Go: `go build ./...`, `go test ./...`
- If ambiguous, check CLAUDE.md for documented commands

Record as `BUILD_CMD` and `TEST_CMD`.

### 0d: State Snapshot
- Record `CURRENT_BRANCH` via `git rev-parse --abbrev-ref HEAD`
- Record `DEFAULT_BRANCH` via `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` (or `glab` equivalent)
- Record `IS_DIRTY` via `git status --porcelain`
- Check for `.changelog/` directory → `HAS_CHANGELOG`
- Check for existing `../makegood-*` worktrees: `git worktree list`. If found, inform the user and ask whether to resume (use existing worktree) or clean up (remove it and start fresh)

## Phase 1: Unified Audit

Read the project's CLAUDE.md files first to understand conventions. Pass relevant conventions to each agent.

Launch 7 Explore agents in two batches. Each agent must report findings in this format:
```
- **[CRITICAL/HIGH/MEDIUM/LOW]** `file:line` - Description. Suggested fix: ... Complexity: Simple/Medium/Complex
```

### Batch 1 (5 parallel Explore agents via Task tool):

1. **Security & Secrets**
   Sources: authentication checks, credential exposure, infrastructure security, input validation, dependency health
   Focus: hardcoded credentials, API keys, exposed secrets, authentication bypasses, disabled security checks, PII exposure, injection vulnerabilities (SQL/command/path traversal), insecure CORS configurations, missing auth checks, unsanitized user input in file paths or queries, known CVEs in dependencies (check `npm audit` / `cargo audit` / `pip-audit` / `go vuln` output), abandoned or unmaintained dependencies, overly permissive dependency version ranges

2. **Code Quality & Style**
   Sources: code brittleness, convention violations, test workarounds, logging & observability
   Focus: magic numbers, brittle conditionals, hardcoded execution paths, test-specific hacks, narrow implementations that pass specific cases but lack generality, dead/unreachable code, unused imports/variables, violations of CLAUDE.md conventions (try/catch usage, window.alert/confirm, class-based code where functional preferred), anti-patterns specific to the detected tech stack, inconsistent or missing structured logging (raw `console.log`/`print` in production code instead of a logger), missing log levels or correlation IDs, swallowed errors (empty catch blocks, `.catch(() => {})`, bare `except: pass`), missing request/response logging at API boundaries

3. **DRY & YAGNI**
   Sources: duplication patterns, speculative abstractions
   Focus: duplicate code blocks, copy-paste patterns, redundant implementations, repeated inline logic (count duplications per pattern, e.g., "DATA_DIR declared 20+ times"), speculative abstractions, unused features, over-engineered solutions, premature optimization, YAGNI violations

4. **Architecture & SOLID**
   Sources: structural violations, coupling analysis, modularity, API contract quality
   Focus: Single Responsibility violations (god files >500 lines, functions >50 lines doing multiple things), tight coupling between modules, circular dependencies, mixed concerns in single files, dependency inversion violations, classes/modules with too many responsibilities (>20 public methods), deep nesting (>4 levels), long parameter lists, modules reaching into other modules' internals, inconsistent API error response shapes across endpoints, list endpoints missing pagination, missing rate limiting on public endpoints, inconsistent request/response envelope patterns

5. **Bugs, Performance & Error Handling**
   Sources: runtime safety, resource management, async correctness, performance, race conditions
   Focus: missing `await` on async calls, unhandled promise rejections, null/undefined access without guards, off-by-one errors, incorrect comparison operators, mutation of shared state, resource leaks (unbounded caches/maps, unclosed connections/streams), `process.exit()` in library code, async routes without error forwarding, missing AbortController on data fetching, N+1 query patterns (loading related records inside loops), O(n²) or worse algorithms in hot paths, unbounded result sets (missing LIMIT/pagination on DB queries), missing database indexes on frequently queried columns, race conditions (TOCTOU, double-submit without idempotency keys, concurrent writes to shared state without locks, stale-read-then-write patterns), missing connection pooling or pool exhaustion

### Batch 2 (2 agents after Batch 1 completes):

6. **Stack-Specific**
   Dynamically focus based on `PROJECT_TYPE` detected in Phase 0:
   - **Node/React**: missing cleanup in useEffect, stale closures, unstable deps arrays, duplicate hooks across components, re-created functions inside render, missing AbortController, bundle size concerns (large imports that could be tree-shaken or lazy-loaded)
   - **Rust**: unsafe blocks, lifetime issues, unwrap() in non-test code, clippy warnings
   - **Python**: mutable default arguments, bare except clauses, missing type hints on public APIs, sync I/O in async contexts
   - **Go**: unchecked errors, goroutine leaks, defer in loops, context propagation gaps
   - **Web projects (any stack)**: accessibility issues — missing alt text on images, broken keyboard navigation, missing ARIA labels on interactive elements, insufficient color contrast, form inputs without associated labels
   - General: framework-specific security issues, language-specific gotchas, domain-specific compliance, environment variable hygiene (missing `.env.example`, required env vars not validated at startup, secrets in config files that should be in env)

7. **Test Coverage**
   Uses Batch 1 findings as context to prioritize:
   Focus: missing test files for critical modules, untested edge cases, tests that only cover happy paths, mocked dependencies that hide real bugs, areas with high complexity (identified by agents 1-5) but no tests, test files that don't actually assert anything meaningful

Wait for ALL agents to complete before proceeding.

## Phase 2: Plan Generation

1. Read the existing `PLAN.md` (create if it doesn't exist)
2. Consolidate all findings from Phase 1, deduplicating across agents (same file:line flagged by multiple agents → keep the most specific description)
3. Identify **shared utility extractions** — patterns duplicated 3+ times that should become reusable functions. Group these as "Foundation" work for Phase 3b.
4. Add a new section to PLAN.md: `## MakeGood Audit - {YYYY-MM-DD}`

```markdown
## MakeGood Audit - {date}

Summary: {N} findings across {M} files. {X} shared utilities to extract.

### Foundation — Shared Utilities
For each utility: name, purpose, files it replaces, signature sketch.

### Security & Secrets
- [ ] **[CRITICAL]** `file:line` - Description — Fix: ... (Complexity: Simple/Medium/Complex)

### Code Quality
- [ ] **[HIGH]** `file:line` - Description — Fix: ...

### DRY & YAGNI
- [ ] **[MEDIUM]** `file:line` - Description — Fix: ...

### Architecture & SOLID
### Bugs, Performance & Error Handling
### Stack-Specific
### Test Coverage (tracked, not auto-remediated)
```

5. Print a summary table:
```
| Category          | CRITICAL | HIGH | MEDIUM | LOW | Total |
|-------------------|----------|------|--------|-----|-------|
| Security          | ...      | ...  | ...    | ... | ...   |
| Code Quality      | ...      | ...  | ...    | ... | ...   |
| DRY & YAGNI       | ...      | ...  | ...    | ... | ...   |
| Architecture      | ...      | ...  | ...    | ... | ...   |
| Bugs & Perf       | ...      | ...  | ...    | ... | ...   |
| Stack-Specific    | ...      | ...  | ...    | ... | ...   |
| Test Coverage     | ...      | ...  | ...    | ... | ...   |
| TOTAL             | ...      | ...  | ...    | ... | ...   |
```

**GATE: If `--scan-only` was passed, STOP HERE.** Print the summary and exit.

## Phase 3: Worktree Remediation

Only proceed with CRITICAL, HIGH, and MEDIUM findings. LOW and Test Coverage findings remain tracked in PLAN.md but are not auto-remediated.

### 3a: Setup

1. If `IS_DIRTY` is true: `git stash --include-untracked -m "makegood: pre-scan stash"`
2. Set `DATE` to today's date in YYYY-MM-DD format
3. Create the worktree:
   ```bash
   git worktree add ../makegood-{DATE} -b makegood/{DATE}
   ```
4. Set `WORKTREE_DIR` to `../makegood-{DATE}`

### 3b: Foundation Utilities

This phase is done by the team lead (you) directly — NOT delegated to agents — because all subsequent agents depend on these files existing and compiling.

1. Create each shared utility file identified in Phase 2's "Foundation" section
2. Run `{BUILD_CMD}` in the worktree to verify compilation:
   ```bash
   cd {WORKTREE_DIR} && {BUILD_CMD}
   ```
3. If build fails, fix issues before proceeding
4. Commit in the worktree:
   ```bash
   git -C {WORKTREE_DIR} add <specific files>
   git -C {WORKTREE_DIR} commit -m "refactor: add shared utilities for {purpose}"
   ```

If no shared utilities were identified, skip this step.

### 3c: Parallel Remediation

1. Use `TeamCreate` with name `makegood-{DATE}`
2. Use `TaskCreate` for each category that has CRITICAL, HIGH, or MEDIUM findings. Possible categories:
   - Security & Secrets
   - Code Quality & Style
   - DRY & YAGNI
   - Architecture & SOLID
   - Bugs, Performance & Error Handling
   - Stack-Specific
3. Only create tasks for categories that have actionable findings
4. Spawn up to 5 general-purpose agents as teammates

### Agent instructions template:
```
You are {agent-name} on team makegood-{DATE}.

Your task: Fix all {CATEGORY} findings from the MakeGood audit.
Working directory: {WORKTREE_DIR} (this is a git worktree — all work happens here)

Project type: {PROJECT_TYPE}
Build command: {BUILD_CMD}
Test command: {TEST_CMD}

Foundation utilities available (if created):
{list of utility files with brief descriptions}

Findings to address:
{filtered list of CRITICAL/HIGH/MEDIUM findings for this category}

COMMIT STRATEGY — commit early and often:
- After completing each logical group of related fixes, stage those files
  and commit immediately with a descriptive conventional commit message.
- Each commit should be independently valid (build should pass).
- Run {BUILD_CMD} in {WORKTREE_DIR} before each commit to verify.
- Use `git -C {WORKTREE_DIR} add <specific files>` — never `git add -A` or `git add .`
- Use `git -C {WORKTREE_DIR} commit -m "prefix: description"`
- Use conventional commit prefixes: fix:, refactor:, feat:, security:
- Do NOT include co-author or generated-by annotations in commits.
- Do NOT bump the version — that happens once at the end.

After all fixes:
- Ensure all changes are committed (no uncommitted work)
- Mark your task as completed via TaskUpdate
- Report: commits made, files modified, findings addressed, any skipped issues

CONFLICT AVOIDANCE:
- Only modify files listed in your assigned findings
- If you need to modify a file assigned to another agent, skip that change and report it
```

### Conflict avoidance:
- Review all findings before task assignment. If two categories touch the same file, assign both sets of findings to the same agent.
- Security agent gets priority on validation logic; DRY agent gets priority on import consolidation.

## Phase 4: Verification

After all agents complete:

1. Run the full build in the worktree:
   ```bash
   cd {WORKTREE_DIR} && {BUILD_CMD}
   ```
2. Run tests in the worktree:
   ```bash
   cd {WORKTREE_DIR} && {TEST_CMD}
   ```
3. If build or tests fail:
   - Identify which commits caused the failure via `git bisect` or manual review
   - Attempt to fix in a new commit: `fix: resolve build/test failure from {category} changes`
   - If unfixable, revert the problematic commit(s): `git -C {WORKTREE_DIR} revert <sha>` and note which findings were skipped
4. Shut down all agents via `SendMessage` with `type: "shutdown_request"`
5. Clean up team via `TeamDelete`

## Phase 5: PR Creation & SemVer

### 5a: Version Bump

1. Collect all commits on the `makegood/{DATE}` branch not on the base branch:
   ```bash
   git -C {WORKTREE_DIR} log {DEFAULT_BRANCH}..HEAD --oneline
   ```
2. Analyze commit prefixes to determine the aggregate SemVer bump:
   - Any `breaking:` or `BREAKING CHANGE` → **major**
   - Any `feat:` → **minor**
   - Otherwise (fix:, refactor:, security:, chore:) → **patch**
   - Use the **highest applicable level**
3. Bump the version (Node.js example; adapt for other project types):
   ```bash
   cd {WORKTREE_DIR} && npm version {LEVEL} --no-git-tag-version
   ```
   For non-Node projects: update the version in the appropriate manifest (Cargo.toml, pyproject.toml, etc.)
4. If `HAS_CHANGELOG` is true:
   - Read the current version from the manifest
   - Add entries to `.changelog/v{major}.{minor}.x.md` summarizing the changes by category
5. Commit the version bump:
   ```bash
   git -C {WORKTREE_DIR} add package.json package-lock.json
   git -C {WORKTREE_DIR} commit -m "chore: bump version to {NEW_VERSION}"
   ```
   Include changelog file in the commit if updated.

### 5b: Push & Create PR

1. Push the branch:
   ```bash
   git -C {WORKTREE_DIR} push -u origin makegood/{DATE}
   ```
   If push fails: `git -C {WORKTREE_DIR} pull --rebase --autostash && git -C {WORKTREE_DIR} push -u origin makegood/{DATE}`

2. Create the PR/MR:

   **GitHub:**
   ```bash
   gh pr create --head makegood/{DATE} --base {DEFAULT_BRANCH} --title "makegood: audit & remediation {DATE}" --body "$(cat <<'EOF'
   ## MakeGood Audit & Remediation

   ### Summary
   - **Findings**: {TOTAL} across {FILES} files ({CRITICAL} critical, {HIGH} high, {MEDIUM} medium)
   - **Fixed**: {FIXED} findings in {COMMITS} commits
   - **Skipped**: {SKIPPED} findings (tracked in PLAN.md)

   ### Changes by Category
   {for each category: name, count fixed, key commits}

   ### Files Modified
   {list of modified files grouped by category}
   EOF
   )"
   ```

   **GitLab:**
   ```bash
   glab mr create --source-branch makegood/{DATE} --target-branch {DEFAULT_BRANCH} --title "makegood: audit & remediation {DATE}" --description "..."
   ```

3. Record `PR_NUMBER` and `PR_URL` from the creation output.

**GATE: If `--no-merge` was passed, STOP HERE.** Print PR/MR URL and summary.

**GATE: If `VCS_HOST` is `gitlab`, STOP HERE.** Print MR URL and summary. GitLab does not support the Copilot review loop.

## Phase 6: Copilot Review Loop (GitHub only)

Maximum 5 iterations to prevent infinite loops. Track `REVIEW_ITERATION = 0`.

### 6.1: Open the PR in the browser

1. Navigate to `PR_URL` using `browser_navigate` via Playwright MCP
2. Check if the user is logged into GitHub (look for user avatar/menu)
3. If not logged in: navigate to `https://github.com/login`, inform the user "Please log in to GitHub in the browser", and wait for confirmation before proceeding

### 6.2: Request Copilot review

**Try the API first:**
```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/requested_reviewers --method POST --input - <<< '{"reviewers":["copilot-pull-request-reviewer"]}'
```

If this returns 422 ("not a collaborator"), **fall back to Playwright**:
1. Navigate to `PR_URL`
2. Click the "Reviewers" gear button in the PR sidebar
3. Click the Copilot review request button:
   ```js
   () => { document.querySelector('button[name="suggested_reviewer_id"]')?.click(); }
   ```
4. Verify the sidebar shows "Awaiting requested review from Copilot"

### 6.3: Poll for review completion

Poll every 15 seconds, max 3 minutes (12 polls):
```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews --jq '.[] | "\(.user.login): \(.state)"'
```

Also check for inline comments:
```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments --jq '.[] | "\(.user.login) [\(.path):\(.line)]: \(.body[:120])"'
```

The review is complete when a `copilot[bot]` review appears.

### 6.4: Check for unresolved threads

Fetch review threads via GraphQL using stdin JSON (**never use `$variables`** — shell expansion consumes `$` signs):
```bash
echo '{"query":"{ repository(owner: \"{OWNER}\", name: \"{REPO}\") { pullRequest(number: {PR_NUMBER}) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 10) { nodes { body path line author { login } } } } } } } }"}' | gh api graphql --input -
```
Save to `/tmp/makegood_threads.json` for parsing.

- If **no unresolved threads** → proceed to 6.6 (merge)
- If **unresolved threads exist** → proceed to 6.5 (fix)

### 6.5: Fix unresolved threads

For each unresolved thread:
1. Read the referenced file in the worktree and understand the feedback
2. Make the code fix in `{WORKTREE_DIR}`
3. Run `{BUILD_CMD}` in the worktree
4. If build passes, commit:
   ```bash
   git -C {WORKTREE_DIR} add <specific files>
   git -C {WORKTREE_DIR} commit -m "address review: {summary of change}"
   ```
5. Resolve the thread via GraphQL mutation using stdin JSON:
   ```bash
   echo '{"query":"mutation { resolveReviewThread(input: {threadId: \"{THREAD_ID}\"}) { thread { id isResolved } } }"}' | gh api graphql --input -
   ```

After all threads are resolved:
1. Push: `git -C {WORKTREE_DIR} push`
2. Increment `REVIEW_ITERATION`
3. If `REVIEW_ITERATION >= 5`: inform the user "Reached max review iterations (5). Remaining issues may need manual review." and proceed to merge.
4. Otherwise: go back to step 6.2 (re-request Copilot review)

### 6.6: Merge

```bash
gh pr merge {PR_NUMBER} --merge
```

Verify the merge:
```bash
gh pr view {PR_NUMBER} --json state,mergedAt
```

If merge fails (e.g., branch protection), inform the user and suggest manual merge.

## Phase 7: Cleanup

1. Remove the worktree:
   ```bash
   git worktree remove {WORKTREE_DIR}
   ```
2. Delete the local branch (only if merged):
   ```bash
   git branch -d makegood/{DATE}
   ```
3. Restore stashed changes (if stashed in Phase 3a):
   ```bash
   git stash pop
   ```
4. Update PLAN.md:
   - Mark completed findings with `[x]`
   - Add the PR/MR link to the section header
   - Note any skipped findings with reasons
5. Print the final summary table:

```
| Phase              | Findings | Fixed | Skipped | Commits | PR/MR      |
|--------------------|----------|-------|---------|---------|------------|
| Security & Secrets | ...      | ...   | ...     | ...     | #{number}  |
| Code Quality       | ...      | ...   | ...     | ...     |            |
| DRY & YAGNI        | ...      | ...   | ...     | ...     |            |
| Architecture       | ...      | ...   | ...     | ...     |            |
| Bugs & Perf        | ...      | ...   | ...     | ...     |            |
| Stack-Specific     | ...      | ...   | ...     | ...     |            |
| Test Coverage      | ...      | (tracked only) | ...     |            |
| TOTAL              | ...      | ...   | ...     | ...     |            |
```

## Error Recovery

- **Agent failure**: continue with remaining agents, note gaps in the summary
- **Build failure in worktree**: attempt fix in a new commit; if unfixable, revert problematic commits and ask the user
- **Push failure**: `git -C {WORKTREE_DIR} pull --rebase --autostash` then retry push
- **Copilot timeout** (review not received within 3 min): inform user, offer to merge without review approval or wait longer
- **Copilot review loop exceeds 5 iterations**: stop iterating, inform user of remaining issues, proceed to merge
- **Existing worktree found at startup**: ask user — resume (reuse worktree) or cleanup (remove and start fresh)
- **`gh auth status` / `glab auth status` failure**: halt and tell user to authenticate first
- **No findings above LOW**: skip Phases 3-7, print "No actionable findings" with the LOW summary

## GraphQL Shell Escaping Rules

The `gh api graphql -f query='...'` approach does NOT work because `$` is consumed by shell expansion. **The only reliable method**: inline all values into the query string and pipe the full JSON request body via stdin:
```bash
echo '{"query":"mutation { resolveReviewThread(input: {threadId: \"THREAD_ID\"}) { thread { id isResolved } } }"}' | gh api graphql --input -
```

Never use `$variables` in GraphQL queries. Never use `-f query=` with dollar signs. Always use stdin JSON piping.

## Notes

- This command is project-agnostic: it reads CLAUDE.md for project-specific conventions and auto-detects the tech stack
- All remediation happens in an isolated worktree — the user's working directory is never modified
- One worktree, one branch, one PR — individual commits per logical change with conventional prefixes
- Version bump happens exactly once (Phase 5a) based on aggregate commit analysis, not per commit
- Only CRITICAL, HIGH, and MEDIUM findings are auto-remediated; LOW and Test Coverage remain tracked in PLAN.md
- Do not include co-author or generated-by info in any commits, PRs, or output
- GitLab projects skip the Copilot review loop entirely (Phase 6) and stop after MR creation
- Always run `gh auth status` (or `glab auth status`) before any authenticated operation

---
description: Scan codebase to infer project goals, clarify with user, and generate GOALS.md
argument-hint: "[--refresh] [focus hint, e.g. 'just the CLI']"
---

# MakeGoals — Generate a GOALS.md from Codebase Analysis

Scan the codebase to infer the project's goals, purpose, and direction, then collaborate with the user to produce a comprehensive `GOALS.md` at the repo root.

Parse `$ARGUMENTS` for:
- **`--refresh`**: re-scan and update an existing GOALS.md rather than creating from scratch
- **Focus hints**: e.g., "focus on API goals", "just the CLI"

## Phase 1: Discovery

Gather signals about the project's purpose and intent from multiple sources. Launch these as parallel Explore agents:

### Agent 1: Identity & Purpose
Scan for project identity signals:
- `README.md`, `README.*` — project description, tagline, stated purpose
- `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` — name, description, keywords, repository URL
- `CLAUDE.md` — design principles, conventions, stated goals
- `PLAN.md` — planned work, roadmap items, in-progress features
- `LICENSE` — licensing intent (open source, proprietary, etc.)
- `.github/FUNDING.yml`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` — community/ecosystem intent
- Marketing or landing page content if present

Extract: project name, stated purpose, target audience, licensing model, community intent.

### Agent 2: Architecture & Capabilities
Scan for what the project actually does:
- Entry points (`main.*`, `index.*`, `app.*`, `cli.*`, `server.*`, binary targets)
- Exported public APIs, routes, endpoints, CLI commands
- Configuration schemas and environment variables
- Database schemas/migrations — what data is modeled
- Key domain types/interfaces — what concepts exist
- Infrastructure files (`Dockerfile`, `docker-compose.*`, CI/CD configs, deploy scripts)

Extract: list of capabilities, deployment model, key domain concepts.

### Agent 3: Evolution & Direction
Scan for trajectory signals:
- Recent git log (last 30 commits): `git log --oneline -30`
- Open issues (if available): `gh issue list --limit 20 --state open 2>/dev/null`
- Open PRs: `gh pr list --limit 10 --state open 2>/dev/null`
- `CHANGELOG.md` or `.changelog/` — recent changes and themes
- `TODO` / `FIXME` / `HACK` comments in source
- `PLAN.md` — incomplete items represent intended direction
- Branch names: `git branch -a --list '*feature*' --list '*feat*' 2>/dev/null`

Extract: recent themes, planned direction, known gaps, active work areas.

Wait for all agents to complete.

## Phase 2: Synthesis

Consolidate the findings into a draft goals structure:

1. **Project Purpose** — one-paragraph summary of what this project is and why it exists
2. **Core Goals** — the 3-7 primary objectives the project is working toward (inferred from what exists + what's planned)
3. **Non-Goals** — things the project explicitly does NOT aim to do (inferred from architectural boundaries, missing features that seem intentional, stated constraints)
4. **Target Users** — who this is for (inferred from README, API design, CLI UX, documentation tone)
5. **Current State** — brief assessment of where the project is now relative to its goals
6. **Direction** — where the project appears to be heading based on recent work and plans

For each goal, assign a confidence level:
- **HIGH** — directly stated in docs or clearly evidenced by code
- **MEDIUM** — strongly implied by patterns, architecture, or recent work
- **LOW** — inferred/speculative, needs user confirmation

## Phase 3: User Clarification

Present the draft to the user and ask targeted questions to resolve uncertainty. Use `AskUserQuestion` for each area that needs input.

### 3a: Purpose Validation
Show the inferred one-paragraph purpose statement. Ask if it's accurate or needs refinement.

### 3b: Goal Prioritization
Present the inferred goals list. For each LOW or MEDIUM confidence goal, ask the user:
- Is this actually a goal?
- How would you rephrase it?
- What priority is it (primary, secondary, stretch)?

### 3c: Missing Goals
Ask: "Are there any goals I missed that aren't yet reflected in the codebase?" Present 2-3 suggested possibilities based on common patterns for this type of project, to prompt the user's thinking.

### 3d: Non-Goals Validation
Present the inferred non-goals. Ask: "Are these accurate? Anything to add or remove?"

### 3e: Target Users
Present the inferred target user description. Ask if it's accurate.

### 3f: Success Criteria (optional)
Ask: "Would you like to define measurable success criteria for any of these goals?" Offer examples relevant to the project type (e.g., "support N concurrent users", "< Xms response time", "100% test coverage on core module").

## Phase 4: Document Generation

Using the validated and refined information, generate `GOALS.md` at the repo root.

### Document Structure

```markdown
# {Project Name} — Goals

> {One-sentence purpose statement}

## Purpose

{One-paragraph expanded purpose statement explaining what the project is, why it exists, and the problem it solves.}

## Core Goals

{Ordered by priority. Each goal has a clear, actionable description.}

### 1. {Goal Title}
{2-3 sentence description of the goal, what success looks like, and why it matters.}

### 2. {Goal Title}
...

## Secondary Goals

{Goals that are important but not primary drivers.}

- **{Goal}**: {Brief description}
- ...

## Non-Goals

{Explicit boundaries — things this project intentionally does NOT do.}

- **{Non-goal}**: {Why this is out of scope}
- ...

## Target Users

{Who this project serves and how they use it.}

## Current State

{Honest assessment of where the project stands relative to its goals.}

| Goal | Status | Notes |
|------|--------|-------|
| {Goal 1} | {Not Started / In Progress / Complete} | {Brief note} |
| ... | ... | ... |

## Direction

{Where the project is heading next, based on plans and recent momentum.}

## Success Criteria

{If the user opted in during Phase 3f. Measurable outcomes per goal.}

| Goal | Metric | Target |
|------|--------|--------|
| ... | ... | ... |
```

### Refresh Mode (`--refresh`)

If `--refresh` was passed and `GOALS.md` already exists:
1. Read the existing `GOALS.md`
2. Compare existing goals against current codebase state
3. Identify goals whose status has changed (new progress, completed, abandoned)
4. Present changes to the user for confirmation
5. Update the document in-place, preserving user-written content where possible

## Phase 5: Finalize

1. Write the `GOALS.md` file to the repo root
2. If `PLAN.md` exists, add a reference link: `See [GOALS.md](./GOALS.md) for project goals and direction.` (only if not already present)
3. Print a summary:
   ```
   GOALS.md created with:
   - {N} core goals
   - {M} secondary goals
   - {K} non-goals
   - Status: {current state summary}
   ```
4. Do NOT commit — let the user review and commit when ready (suggest using `/cam` to commit)

## Notes

- This command is project-agnostic — it reads whatever project signals exist
- The goal is collaboration: scan first, then refine with the user — never assume
- LOW confidence inferences should always be validated with the user before inclusion
- Preserve the user's voice — if they provide rephrased goals, use their wording verbatim
- If the project is brand new with minimal code, lean more heavily on user input and less on codebase inference
- If `gh` CLI is not authenticated, skip issue/PR scanning gracefully — don't halt

# Claude Code Commands — Goals

> Automate the software development lifecycle through curated slash commands for Claude Code.

## Purpose

Claude Code Commands is a curated library of slash commands that automate the software development lifecycle within Claude Code. It packages production-grade DevSecOps, code review, planning, and release management workflows as reusable commands — enabling developers to run security audits, create PRs with automated review loops, manage versioning, and maintain project governance through simple slash commands.

## Core Goals

### 1. Automate DevSecOps Workflows
Provide one-command security auditing, code quality analysis, and automated remediation. `/makegood` scans across 7 dimensions (security, code quality, DRY, architecture, bugs, stack-specific issues, test coverage), remediates findings in an isolated worktree, and delivers a clean PR — turning what would be days of manual review into a single command invocation.

### 2. Standardize Development Rituals
Enforce consistent commit practices, SemVer versioning, and changelog management across projects. `/cam` ensures every commit follows conventional commit prefixes, bumps the version appropriately, and updates changelogs — eliminating version drift and inconsistent commit histories.

### 3. Orchestrate AI-Powered Code Review
Integrate Copilot review loops with automated thread resolution into the PR workflow. `/pr` and `/rpr` handle the full cycle: create the PR, request review, parse feedback, fix issues, resolve threads, and iterate — reducing the manual back-and-forth of code review to a supervised automation.

### 4. Maintain Project Governance Documentation
Keep planning and standards documents current and well-structured. `/replan` extracts completed work into permanent docs, `/makegoals` generates project goal documents from codebase analysis, and `/claude:optimize-md` audits CLAUDE.md files against best practices — ensuring project documentation evolves alongside the code.

### 5. Be Project-Agnostic
Auto-detect tech stacks (Node.js, Rust, Python, Go, Java, Ruby, .NET) and adapt build commands, test runners, version bumping, and audit strategies accordingly. Commands should work on any codebase without manual configuration.

## Secondary Goals

- **Serve as a reference implementation**: Demonstrate advanced multi-agent Claude Code patterns (team coordination, parallel agent orchestration, worktree isolation) that others can learn from and adapt for their own commands.
- **Build a community command ecosystem**: Provide a clear contribution model (`install.sh`, modular `.md` files) that enables others to share and distribute their own Claude Code commands.

## Non-Goals

- **Replace CI/CD pipelines**: Commands complement GitHub Actions and GitLab CI by handling code-level workflows. Infrastructure automation, deployment pipelines, and environment management remain outside scope.
- **Provide a GUI or dashboard**: Everything runs in the CLI via Claude Code. There is no web interface or visual tooling planned.
- **Support non-Claude AI tools**: Commands are designed specifically for Claude Code's agent/team model, task coordination, and tool ecosystem. Compatibility with other AI coding assistants is not a goal.

## Target Users

Developers and teams using Claude Code who want to automate repetitive development workflows — particularly those practicing DevSecOps, structured planning, and SemVer-based release management.

## Current State

| Goal | Status | Notes |
|------|--------|-------|
| Automate DevSecOps Workflows | Complete | `/makegood` — 7-agent audit, worktree remediation, PR + Copilot review loop |
| Standardize Development Rituals | Complete | `/cam` — SemVer bump, changelog, conventional commits |
| Orchestrate AI-Powered Code Review | Complete | `/pr`, `/rpr` — full Copilot review cycle with thread resolution |
| Maintain Project Governance Docs | Complete | `/replan`, `/makegoals`, `/claude:optimize-md` |
| Be Project-Agnostic | In Progress | Supports Node.js, Rust, Python, Go, Java, Ruby, .NET detection; edge cases may remain |
| Reference Implementation | In Progress | Commands demonstrate patterns; no formal documentation of patterns yet |
| Community Command Ecosystem | In Progress | `install.sh` distribution works; no contributor guide yet |

## Direction

The command library has just been open-sourced with 7 production-grade commands covering the core development lifecycle. Near-term focus is on:

- Refining existing commands based on real-world usage and community feedback
- Expanding tech stack coverage for edge cases in project detection
- Growing the command catalog as new workflow patterns emerge
- Establishing contribution guidelines to enable community commands

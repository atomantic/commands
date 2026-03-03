# Claude Code Commands [ARCHIVED]

> **This repo has moved to [atomantic/slashdo](https://github.com/atomantic/slashdo)**

slashdo is the successor to this repo, published as an npm package with multi-environment support (Claude Code, OpenCode, Gemini CLI, Codex), automatic format conversion, and self-update notifications.

## Migrate

**1. Remove old commands:**
```bash
./uninstall.sh
```

**2. Install slashdo:**
```bash
npx slash-do@latest
```

This installs all commands under the `/do:` namespace (e.g., `/do:cam`, `/do:pr`, `/do:makegood`).

## Why the move?

- **npm distribution** — `npx slash-do@latest` instead of git clone
- **Multi-environment** — one source of truth, auto-converted for Claude Code, OpenCode, Gemini CLI, and Codex
- **Semver + self-update** — version tracking and `/do:update` command
- **No git dependency** — curl installer available for environments without npm

See the [slashdo README](https://github.com/atomantic/slashdo#readme) for full details.

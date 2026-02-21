# Claude Code Commands

Curated slash commands for Claude Code. This repo is the source of truth — edit here, run `install.sh` to deploy to `~/.claude/commands/`.

## Quick Start

```bash
git clone git@github.com:atomantic/commands.git && cd commands && ./install.sh
```

## Commands

| Command | Description |
|---|---|
| `/cam` | Commit and push all work with SemVer bump and changelog |
| `/makegood` | Unified DevSecOps audit, remediation, PR, and Copilot review loop. **Heavy** — spawns 7+ subagents across two batches, then a remediation team. Expect significant token usage. |
| `/pr` | Create branch, commit, push, and open MR/PR with Copilot review |
| `/replan` | Review and clean up PLAN.md, extract docs from completed work |
| `/rpr` | Resolve PR review feedback with parallel agents |
| `/claude:optimize-md` | Audit and optimize CLAUDE.md files against best practices |

## install.sh

```bash
./install.sh                    # install/update all commands
./install.sh cam pr             # install/update specific commands
./install.sh --list             # show commands and install status
./install.sh --dry-run          # preview changes without applying
./install.sh --dry-run cam      # preview specific command
./install.sh --help             # usage info
```

## How It Works

The `commands/` directory mirrors `~/.claude/commands/` exactly. The install script compares each file:

- **New** commands are copied to the target
- **Changed** commands show a diff, then overwrite
- **Unchanged** commands are skipped
- **Commands in the target but not in this repo** are never touched or deleted

Subdirectories (like `claude/`) are created automatically.

## Adding a New Command

1. Create the `.md` file under `commands/` (use a subdirectory for namespaced commands)
2. Run `./install.sh` to deploy it
3. Commit and push

---
description: Commit and push all work with SemVer bump and changelog
---

# Commit All My Work (cam)

Commit and push all work from this session, updating documentation and version as needed.

## Instructions

1. **Identify changes to commit**:
   - Run `git status` and `git diff --stat` to see what changed
   - If you edited files in this session, commit only those files
   - If invoked without prior edit context, review all uncommitted changes
   - if there are files that should be added to the .gitignore that are not yet there, ensure we have proper .gitignore coverage

2. **Update the changelog**:
   - Find the changelog file at `.changelog/v{major}.{minor}.x.md` (check package.json for current version)
   - Add a concise entry describing the changes under the appropriate section (Added, Changed, Fixed, Removed)
   - If no changelog directory exists, skip this step

3. **Update PLAN.md** (if exists):
   - Mark completed items as done
   - Update progress notes if relevant
   - Skip if no PLAN.md exists or changes aren't plan-related

4. **Bump the version and commit together** (SemVer):
   - Review all changes being committed and classify them:
     - **Major** (breaking): incompatible API changes, removed features, config format changes that break existing setups
     - **Minor** (feature): new functionality, new endpoints, new UI pages/components, new config options (backwards-compatible)
     - **Patch** (fix): bug fixes, performance improvements, refactors, style changes, dependency updates, documentation
   - Use the **highest applicable level** (e.g., if changes include both a bug fix and a new feature, bump minor)
   - Run `npm version <major|minor|patch> --no-git-tag-version` to bump `package.json` and `package-lock.json`
   - Stage all changed files **plus** `package.json` and `package-lock.json` together in a **single commit**
   - Do NOT use `git add -A` or `git add .` - add specific files by name
   - Write a clear, concise commit message describing what was done
   - Do NOT include Co-Authored-By or generated-by annotations
   - Use conventional commit prefix: `feat:` for minor, `fix:` for patch, `breaking:` for major

6. **Push the changes**:
   - Use `git pull --rebase --autostash && git push` to push safely

## Important

- Never stage files you didn't edit
- Never use `git add -A` or `git add .`
- Keep commit messages focused on the "why" not just the "what"
- If there are no changes to commit, inform the user

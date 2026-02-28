---
description: Create a release PR using the project's documented release workflow
---

## Detect Release Workflow

Before doing anything, determine the project's source and target branches for releases. Do NOT hardcode branch names. Instead, discover them:

1. **Source branch** — run `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'` to get the repo's default branch
2. **Target branch** — determine by reading (in priority order):
   - **GitHub Actions workflows** — check `.github/workflows/release.yml` (or similar) for `on: push: branches:` to find the branch that triggers the release pipeline
   - **Project CLAUDE.md** — look for git workflow sections, branch descriptions, or release instructions
   - **Versioning docs** — check `docs/VERSIONING.md`, `CONTRIBUTING.md`, or `RELEASING.md`
   - **Branch convention** — if a `release` branch exists, the target is `release`; otherwise ask the user

Print the detected workflow: `Detected release flow: {source} → {target}`

If ambiguous, ask the user to confirm before proceeding.

## Pre-Release Checks

1. **Ensure you're on the source branch** — checkout if needed
2. **Pull latest** — `git pull --rebase --autostash`
3. **Run tests** — execute the project's test suite (check CLAUDE.md or package.json for the command)
4. **Run build** — execute the project's build command if one exists
5. **Check version** — read `package.json` (or equivalent) version. Confirm with user whether the current version is correct for this release, or if a bump is needed
6. **Check changelog** — look for `.changelog/`, `CHANGELOG.md`, or similar. Summarize what's documented for this release. If the changelog has placeholder dates (e.g., `YYYY-MM-DD`), note it but don't modify — CI handles substitution

## Local Code Review (before opening PR)

Perform a self-review of all changes between source and target:

1. Run `git diff {target}...{source}` to see the full diff
2. Review the diff for:
   - Leftover debug code (console.log, debugger, TODO/FIXME/HACK comments added in this change)
   - Hardcoded secrets, API keys, or credentials
   - Files that shouldn't be committed (.env, node_modules, build artifacts, large binaries)
   - Unused imports or variables introduced by the changes
   - Inconsistent naming or style that deviates from the project's conventions
   - Missing error handling at system boundaries (user input, external APIs)
   - Obvious logic bugs or off-by-one errors
3. If issues are found, fix them, commit, and push before proceeding
4. Summarize the review findings (even if clean) so the user can see what was checked

## Open the Release PR

- Push the source branch to remote
- Create a PR from `{source}` to `{target}`
- Title: `Release v{version}` (read version from package.json or equivalent)
- Body: include the changelog content for this version if available, otherwise summarize commits since last release
- Keep the description clean — no co-author or "generated with" messages

## Copilot Code Review Loop

After the PR is created, run the Copilot review-and-fix loop:

1. **Open the PR in the Playwright MCP browser** to verify the user is logged into GitHub
   - Navigate to the PR URL using `browser_navigate`
   - Confirm the page shows the user is authenticated (user avatar/menu visible, NOT "Sign in" link)
   - **BLOCKING**: If the browser is NOT authenticated, STOP and ask the user to log into GitHub in the Playwright browser before continuing. You MUST have an authenticated browser session to re-request Copilot reviews. Do NOT proceed without it.
   - **IMPORTANT**: When using `browser_snapshot`, do NOT pass a `filename` parameter — this writes files into the repo working directory. Either omit `filename` (returns inline) or use a `/tmp/` path. Never leave snapshot artifacts in the codebase.

2. **Ensure a Copilot review is running**
   - For **public repos**: Copilot review triggers automatically on PR creation — verify by checking the sidebar for "Awaiting requested review from Copilot" or a completed review
   - For **private repos**: Copilot won't auto-trigger — click the "Re-request review" button next to Copilot in the Reviewers sidebar to explicitly request it
   - If no Copilot reviewer is configured at all, inform the user and skip this loop

3. **Wait for the review to complete (BLOCKING — do not skip or proceed early)**
   - Record the current review count and latest `submittedAt` timestamp before waiting
   - Poll using `gh api graphql` to check the `reviews` array for a NEW review node (compare `submittedAt` timestamps or count)
   - The review is complete when a new Copilot review node appears with a `submittedAt` after your latest push
   - **Do NOT merge until the re-requested review has actually posted** — "Awaiting requested review" means it is still in progress
   - Poll every 30-60 seconds; Copilot reviews typically take 2-5 minutes for large PRs

4. **Check for unresolved comments**
   - Use `gh api graphql` to fetch all review threads and filter for `isResolved: false`
   - Also count the total comments in the latest review (check the review body for "generated N comments")
   - If the latest review has **zero comments** (body says "generated 0 comments" or no review threads exist): proceed to merge (step 6)
   - If **there are unresolved comments**: proceed to fix them (step 5)

5. **Fix all unresolved review comments**
   For each unresolved thread:
   - Read the referenced file and understand the feedback
   - Make the code fix
   - Run the build (`npm run build` or the project's build command)
   - If build passes, commit with message `address review: <summary of changes>`
   - Resolve the thread via GraphQL mutation:
     ```
     gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { id isResolved } } }'
     ```
   - After all threads are resolved:
     - Bump the patch version (`npm version patch --no-git-tag-version` or equivalent)
     - Commit the version bump
     - Push all commits to remote
   - **Re-request a Copilot review** (MANDATORY — do NOT skip this step):
     - Use `browser_run_code` to click the re-request button reliably without needing to parse large snapshots:
       ```
       async (page) => {
         const btn = page.getByRole('button', { name: 'Re-request review' });
         if (await btn.isVisible()) { await btn.click(); return 'Clicked'; }
         return 'Not found';
       }
       ```
     - Copilot is a GitHub App — `gh api` reviewer requests do NOT work for it. The browser click is the ONLY reliable method.
     - After clicking, verify the sidebar changes to "Awaiting requested review from Copilot"
   - **Go back to step 3** (wait for new review) — this loop MUST repeat until Copilot returns a review with zero new comments. Never merge after only one round of fixes.

6. **Merge the PR (only after a CLEAN review with zero comments)**
   - **CRITICAL**: Only merge after the latest Copilot review has been submitted AND that review generated **zero comments**. Check this by:
     1. Confirming a new review node exists with `submittedAt` after your last push
     2. Confirming the review body says "generated 0 comments" OR there are no new unresolved threads
   - Never merge if:
     - "Awaiting requested review" is still shown (review in progress)
     - The latest review had comments that you fixed but you didn't get a CLEAN re-review
     - The browser is not authenticated and you couldn't re-request a review
   - Once confirmed clean, merge:
     ```
     gh pr merge <number> --merge
     ```
   - Verify the merge succeeded: `gh pr view <number> --json state,mergedAt`

## Post-Merge

- Report the final status including version, PR URL, and merge state
- Remind the user to check for the GitHub release once CI completes (if the project uses automated releases)
- Switch back to the source branch locally: `git checkout {source} && git pull --rebase --autostash`

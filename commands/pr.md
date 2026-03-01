---
description: Commit, push, and open a PR against the repo's default branch
---

## Detect Branches

1. **Detect the default branch** — run `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'` to get the repo's default branch (e.g., `main`, `master`, `develop`)
2. **Determine the current branch** — use `git branch --show-current`
3. If you're already on the default branch, commit to a new feature branch named after the work being done
4. The PR will target the **default branch** as base

Print: `PR flow: {current_branch} → {default_branch}`

## Commit and Push

- Commit all changes to the current branch
- Keep commit message concise and do not use co-author information
- Push the branch to remote: `git pull --rebase --autostash && git push -u origin {current_branch}`

## Local Code Review (before opening PR)

Before creating the PR, perform a self-review of all changes that will be included:

1. Run `git diff {default_branch}...{current_branch}` to see the full diff
2. Review the diff for:
   - Leftover debug code (console.log, debugger, TODO/FIXME/HACK comments added in this change)
   - Hardcoded secrets, API keys, or credentials
   - Files that shouldn't be committed (.env, node_modules, build artifacts, large binaries)
   - Unused imports or variables introduced by the changes
   - Inconsistent naming or style that deviates from the project's conventions
   - Missing error handling at system boundaries (user input, external APIs)
   - Obvious logic bugs or off-by-one errors
   - Overly broad changes that should be split into separate PRs
3. If issues are found, fix them and amend/recommit before proceeding
4. Summarize the review findings (even if clean) so the user can see what was checked

## Open the PR

- Create a PR from `{current_branch}` to `{default_branch}`
- Create a rich PR description — no co-author or "generated with" messages

## Copilot Code Review Loop

After the PR is created, run the Copilot review-and-fix loop:

1. **Request a Copilot review via API**
   ```bash
   gh api repos/OWNER/REPO/pulls/PR_NUM/requested_reviewers -f 'reviewers[]=copilot-pull-request-reviewer[bot]'
   ```
   **CRITICAL**: The reviewer name MUST include the `[bot]` suffix. Without it, the API returns a 422 "not a collaborator" error.
   - For **public repos**: Copilot review may trigger automatically on PR creation — check if a review already exists before requesting
   - If no Copilot reviewer is configured at all, inform the user and skip this loop

2. **Wait for the review to complete (BLOCKING — do not skip or proceed early)**
   - Record the current review count and latest `submittedAt` timestamp before waiting
   - Poll using `gh api graphql` to check the `reviews` array for a NEW review node (compare `submittedAt` timestamps or count):
     ```bash
     gh api graphql -f query='{ repository(owner: "OWNER", name: "REPO") { pullRequest(number: PR_NUM) { reviews(last: 3) { nodes { state body author { login } submittedAt } } reviewThreads(first: 100) { nodes { id isResolved comments(first: 3) { nodes { body path line author { login } } } } } } } }'
     ```
   - The review is complete when a new Copilot review node appears with a `submittedAt` after your latest push
   - **Do NOT merge until the re-requested review has actually posted** — "Awaiting requested review" means it is still in progress
   - Poll every 30-60 seconds; Copilot reviews typically take 1-3 minutes

3. **Check for unresolved comments**
   - Filter review threads for `isResolved: false`
   - Also count the total comments in the latest review (check the review body for "generated N comments")
   - If the latest review has **zero comments** (body says "generated 0 comments" or no unresolved threads exist): the PR is clean
   - If **there are unresolved comments**: proceed to fix them (step 4)

4. **Fix all unresolved review comments**
   For each unresolved thread:
   - Read the referenced file and understand the feedback
   - Make the code fix
   - Run the build (`npm run build` or the project's build command)
   - If build passes, commit with message `address review: <summary of changes>`
   - Resolve the thread via GraphQL mutation:
     ```bash
     gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { id isResolved } } }'
     ```
   - After all threads are resolved:
     - Bump the patch version (`npm version patch --no-git-tag-version` or equivalent)
     - Commit the version bump
     - Push all commits to remote
   - **Re-request a Copilot review** via API (same command as step 1)
   - **Go back to step 2** (wait for new review) — this loop MUST repeat until Copilot returns a review with zero new comments. Never merge after only one round of fixes.

5. **Report the final status** to the user including PR URL and review outcome

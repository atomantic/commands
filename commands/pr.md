---
description: Create branch, commit, push, and open MR/PR
---

- Use git and the appropriate glab or gh cli tool to commit changes, push to remote, and open a pull request.
- Commit all changes to the `dev` branch (checkout dev if not already on it)
- Push the dev branch to remote

## Local Code Review (before opening PR)

Before creating the PR, perform a self-review of all changes that will be included:

1. Run `git diff main...dev` (or the appropriate base branch) to see the full diff
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

- Create a PR from `dev` to `main`
- Keep commit message concise and do not use co-author information
- Create a rich PR description, also without co-author or "generated with claude" message

## Copilot Code Review Loop

After the PR is created, run the Copilot review-and-fix loop:

1. **Open the PR in the Playwright MCP browser** to verify the user is logged into GitHub
   - Navigate to the PR URL using `browser_navigate`
   - Confirm the page shows the user is authenticated (user avatar/menu visible)

2. **Ensure a Copilot review is running**
   - For **public repos**: Copilot review triggers automatically on PR creation — verify by checking the sidebar for "Awaiting requested review from Copilot" or a completed review
   - For **private repos**: Copilot won't auto-trigger — click the "Re-request review" button next to Copilot in the Reviewers sidebar to explicitly request it
   - If no Copilot reviewer is configured at all, inform the user and skip this loop

3. **Wait for the review to complete (BLOCKING — do not skip or proceed early)**
   - Poll using `gh api graphql` to check the `reviews` array for a NEW review node (compare `submittedAt` timestamps or count)
   - The review is complete when a new Copilot review node appears with a `submittedAt` after your latest push
   - **Do NOT merge until the re-requested review has actually posted** — "Awaiting requested review" means it is still in progress
   - Poll every 30-60 seconds; Copilot reviews typically take 2-5 minutes for large PRs

4. **Check for unresolved comments**
   - Use `gh api graphql` to fetch all review threads and filter for `isResolved: false`
   - If **no unresolved comments**: proceed to merge (step 6)
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
     - Bump the patch version (`npm version patch --no-git-tag-version -ws --include-workspace-root` or equivalent)
     - Commit the version bump
     - Push all commits to remote
   - **Re-request a Copilot review**: click the "Re-request review" button in the browser or use the GitHub API
   - Go back to step 3 (wait for review)

6. **Merge the PR (only after final review completes)**
   - **CRITICAL**: Only merge after the latest Copilot review has been submitted (a new review node exists in the GraphQL response). Never merge while "Awaiting requested review" is shown.
   - Once Copilot returns a review with **no new comments**, merge:
     ```
     gh pr merge <number> --merge
     ```
   - Verify the merge succeeded: `gh pr view <number> --json state,mergedAt`
   - Report the final status to the user

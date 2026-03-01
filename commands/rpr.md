---
description: Resolve PR review feedback with parallel agents
---

# Resolve PR Review Feedback

Address the latest code review feedback on the current branch's pull request using a team-based approach.

## Steps

1. **Get the current PR and determine repo ownership**: Use `gh pr view --json number,url,reviewDecision,reviews,headRefName,baseRefName` to find the PR for this branch. Parse owner/name from `gh repo view --json owner,name`. Also check the PR's base repository owner — if the PR targets an upstream repo you don't own (i.e., a fork-to-upstream PR), note this as `is_fork_pr=true`. You can detect this by comparing the PR URL's owner against your authenticated user (`gh api user --jq .login`).

2. **Request Copilot code review** (only if `is_fork_pr=false`): Follow the "Requesting GitHub Copilot Code Review" section below to request a review, then poll until the review is complete before proceeding. **Skip this step entirely for fork-to-upstream PRs** — you don't have permission to request reviewers on repos you don't own.

3. **Fetch review comments**: Use `gh api graphql` with stdin JSON to get all unresolved review threads. **CRITICAL: Do NOT use `$variables` in GraphQL queries — shell expansion consumes `$` signs.** Always inline values and pipe JSON via stdin:
   ```bash
   echo '{"query":"{ repository(owner: \"OWNER\", name: \"REPO\") { pullRequest(number: PR_NUM) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 10) { nodes { body path line author { login } } } } } } } }"}' | gh api graphql --input -
   ```
   Save results to `/tmp/pr_threads.json` for parsing.

4. **Spawn a team to address feedback in parallel**:
   - Create a team with `TeamCreate`
   - Create a task for each unresolved review thread using `TaskCreate`
   - Create an additional task for an **independent code quality review** of all files changed in the PR (`gh pr diff --name-only`)
   - Spawn sub-agents (general-purpose type) as teammates to handle each task in parallel:
     - One agent per review thread (or group closely related threads on the same file)
     - One dedicated agent for the code quality review
   - Each agent should:
     - Read the file and understand the context of the feedback
     - Make the requested code changes if they are accurate and warranted
     - Look for further opportunities to DRY up affected code
     - Report back what was changed and the thread ID that was addressed
   - The code quality reviewer should:
     - Read all changed files in the PR
     - Check for: style violations, missing error handling, dead code, DRY violations, security issues
     - Apply fixes directly and report what was changed
   - Wait for all agents to complete, then review their changes

5. **Run tests**: Run the project's test suite to verify all changes pass. Do not proceed if tests fail — fix issues first.

6. **Commit and push**:
   - Stage all changed files and commit with a descriptive message summarizing what was addressed. Do not include co-author info.
   - Push to the branch.

8. **Resolve conversations**: For each addressed thread, resolve it via GraphQL mutation using stdin JSON. **Never use `$variables` in the query — inline the thread ID directly**:
   ```bash
   echo '{"query":"mutation { resolveReviewThread(input: {threadId: \"THREAD_ID_HERE\"}) { thread { id isResolved } } }"}' | gh api graphql --input -
   ```

9. **Request another Copilot review** (only if `is_fork_pr=false`): After pushing fixes, request a fresh Copilot code review and repeat from step 3 until the review passes clean. **Skip for fork-to-upstream PRs.**

10. **Report summary**: Print a table of all threads addressed with file, line, and a brief description of the fix.

## GraphQL Shell Escaping Rules

The `gh api graphql -f query='...'` approach **does not work** in this environment because `$` is consumed by shell expansion. All of these approaches fail:
- Single-quoted inline queries
- Shell variable assignment
- File + `$(cat)` subshell
- Escaped `\$` dollar signs

**The only reliable method**: Inline all values into the query string and pipe the full JSON request body via stdin:
```bash
echo '{"query":"mutation { resolveReviewThread(input: {threadId: \"PRRT_abc123\"}) { thread { id isResolved } } }"}' | gh api graphql --input -
```

## Requesting GitHub Copilot Code Review

**WARNING**: Do NOT use `@copilot review` in a PR comment — this triggers the **Copilot coding agent** which opens a new PR instead of performing a code review.

### Step 1: Try the API first
```bash
gh api repos/OWNER/REPO/pulls/PR_NUM/requested_reviewers --method POST --input - <<< '{"reviewers":["copilot-pull-request-reviewer"]}'
```

If this returns 422 "not a collaborator", fall through to Step 2.

### Step 2: Use Playwright (browser-based)

The API may fail because `copilot-pull-request-reviewer` is a GitHub App, not a user collaborator. Use Playwright MCP to request the review through the GitHub UI:

1. **Navigate to the PR**: `browser_navigate` to `https://github.com/OWNER/REPO/pull/PR_NUM`
2. **Check if logged in**: If the page shows a login form, navigate to `https://github.com/login`, tell the user "Please log in to GitHub in the browser" and **wait for the user to confirm they are logged in** before proceeding
3. **Open the Reviewers dropdown**: `browser_click` on the "Reviewers" gear button in the PR sidebar
4. **Click the Copilot reviewer**: The dropdown shows a "Suggestions" section with "Copilot code review" and a "Request" button next to it. The Request button has an element ID like `#suggested-reviewier-NNNN` (note: GitHub has a typo — `reviewier` not `reviewer`). Click it using `browser_evaluate`:
   ```js
   () => { document.querySelector('button[name="suggested_reviewer_id"]')?.click(); }
   ```
5. **Verify**: The sidebar should now show "Awaiting requested review from Copilot"

### Step 3: Poll for review completion
```bash
# Poll every 15 seconds until reviews appear
gh api repos/OWNER/REPO/pulls/PR_NUM/reviews --jq '.[] | "\(.user.login): \(.state)"'
```

Also check for inline review comments:
```bash
gh api repos/OWNER/REPO/pulls/PR_NUM/comments --jq '.[] | "\(.user.login) [\(.path):\(.line)]: \(.body[:120])"'
```

Copilot reviews typically take 30-90 seconds. Poll every 15 seconds until results appear.

## Notes

- Only resolve threads where you've actually addressed the feedback
- If feedback is unclear or incorrect, leave a reply comment instead of resolving
- Do not include co-author info in commits
- For small PRs (1-3 threads), sub-agents may be overkill — use judgment on whether to spawn a team or handle inline
- Always run tests before committing — never push code with known failures
- Shut down the team after all work is complete

# Replan Command

You are tasked with reviewing and updating the PLAN.md file to keep it clean, current, and action-oriented.

## Your Responsibilities

### 1. Review PLAN.md Structure
- Read the entire PLAN.md file
- Identify completed items (marked with [x]) that have detailed documentation
- Identify sections that should be moved to permanent documentation

### 2. Extract Documentation from Completed Work
For each completed item with substantial documentation:
- Determine the appropriate docs location (create docs/ directory if needed)
- Extract the detailed documentation sections
- Move them to appropriate docs files with proper formatting
- Follow existing documentation patterns if they exist

**Common docs files to consider:**
- `docs/ARCHITECTURE.md` - System design, data flow, architecture
- `docs/API.md` - API endpoints, schemas, events
- `docs/TROUBLESHOOTING.md` - Common issues and solutions
- `docs/features/*.md` - Individual feature documentation
- `README.md` - User-facing documentation

### 3. Clean Up PLAN.md
After moving documentation:
- Replace detailed documentation with a brief summary (1-3 sentences)
- Add a reference link to the docs file where details were moved
- Keep completion status ([x] for completed, [ ] for pending)
- Remove redundant or outdated information
- Keep any quick reference sections up to date

**Example transformation:**
```markdown
Before:
- [x] Feature X: Authentication System

### Architecture
- **Auth Service**: Core authentication logic
- **JWT Tokens**: Token generation and validation
[... 50 more lines of detailed docs ...]

After:
- [x] Feature X: Authentication System - JWT-based auth with session management. See [Authentication](./docs/features/authentication.md)
```

### 4. Update Documentation Index
- Ensure PLAN.md references all relevant docs files
- Add any new docs files you created
- Verify all links are correct
- Add a Documentation section if it doesn't exist

### 5. Focus on Next Actions
At the end of PLAN.md:
- Add or update a "## Next Actions" section
- List 3-5 concrete next steps based on:
  - Incomplete items
  - Recent git commits (if in a repo)
  - Areas that need attention
- Make these action items specific and actionable

### 6. Commit Your Changes
After reorganizing (if in a git repository):
- Commit changes with a clear message like:
  ```
  docs: reorganize PLAN.md and extract completed work to docs

  - Moved completed feature docs to docs/features/
  - Updated PLAN.md to focus on next actions
  - Added Next Actions section
  ```

## Guidelines

- **Be thorough**: Read all completed items and assess documentation value
- **Be surgical**: Only move substantial documentation (>20 lines), keep brief summaries in PLAN
- **Be organized**: Group related content in docs files with clear headings
- **Be consistent**: Match the style and format of existing docs files
- **Be helpful**: Make it easy to find information by adding clear references

## Example Output Structure

After running `/replan`, the PLAN.md should have:
```markdown
# Project Name - Implementation Plan

## Quick Reference
[... existing quick reference ...]

## Completed
- [x] Feature A - See [Feature A Docs](./docs/features/feature-a.md)
- [x] Feature B - See [Feature B Docs](./docs/features/feature-b.md)

## In Progress
- [ ] Feature C: Brief description of current work

## Planned
- [ ] Feature D: Brief description of planned work

## Documentation
- [Architecture Overview](./docs/ARCHITECTURE.md)
- [API Reference](./docs/API.md)
- [Feature A](./docs/features/feature-a.md)
- [Feature B](./docs/features/feature-b.md)

## Next Actions

1. **Task 1**: Brief description of what needs to be done
2. **Task 2**: Brief description of next task
3. **Task 3**: Brief description of another task
4. **Task 4**: Brief description of testing needed
5. **Task 5**: Brief description of deployment or final step
```

## Notes

- Don't delete information - move it to appropriate docs files
- Keep related information consolidated in single docs files
- Create feature-specific docs in docs/features/ for complex systems
- Preserve all historical information but organize it better
- If no PLAN.md exists, inform the user rather than creating one
- Adapt to the existing structure and conventions of the project

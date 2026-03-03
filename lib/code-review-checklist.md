   **Hygiene**
   - Leftover debug code (console.log without emoji prefix, debugger, TODO/FIXME/HACK)
   - Hardcoded secrets, API keys, or credentials
   - Files that shouldn't be committed (.env, node_modules, build artifacts)
   - Overly broad changes that should be split into separate PRs

   **Imports & references**
   - Every symbol used in the file is imported (missing imports → runtime crash)
   - No unused imports introduced by the changes

   **Runtime correctness**
   - State/variables that are declared but never updated or only partially wired up (e.g. a state setter that's never called with `true`)
   - Side effects during React render (setState, navigation, mutations outside useEffect)
   - Off-by-one errors, null/undefined access without guards

   **Resource management**
   - Event listeners, socket handlers, subscriptions, and timers are cleaned up on unmount/teardown
   - useEffect cleanup functions remove everything the effect sets up

   **Validation & consistency**
   - New endpoints/schemas match validation standards of similar existing endpoints (check for field limits, required fields, types)
   - New API routes have the same error handling patterns as existing routes

   **Style & conventions**
   - Naming and patterns consistent with the rest of the codebase
   - Missing error handling at system boundaries (user input, external APIs)

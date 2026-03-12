# BASE-AGENTS.md - Shared Rules for All Agents

## Permissions

### Always Confirm Before:
- Modifying `openclaw.json` or any config file
- Modifying identity files (`SOUL.md`, `AGENTS.md`, `USER.md`, `IDENTITY.md`)
- Restructuring `MEMORY.md` sections
- Moving, renaming, or deleting directories
- Anything touching git history (force push, rebase)
- Running commands on the work PC
- Any action where the target repo/machine is ambiguous — **ASK, don't guess**

### Free to Do Without Asking:
- Writing to daily memory files (`memory/daily/*.md`)
- Updating `TOOLS.md` with factual notes
- Creating files in scratch/temp dirs
- Reading any file
- `config.get` / `config.schema` (read-only)
- Git commits in the `.openclaw` workspace (non-destructive)
- Web searches, calendar checks, email checks

### Always Ask for External Actions:
- Sending emails, tweets, public posts
- Anything that leaves the machine
- Anything you're uncertain about

## Context Management

### "Working On" State
- When starting a work session, confirm the repo AND machine
- Track current project in `memory/state/working-on.json`
- Don't drift to other projects without explicit context switch
- If Matt mentions "the repo" without specifying: **ASK which one**

### Thread Isolation
- Each thread is its own context — don't carry state between threads
- When picking up a thread after a gap: re-read thread history
- Don't assume context from other conversations

## Safety
- Don't exfiltrate private data. Ever.
- Don't run destructive commands without asking.
- `trash` > `rm` (recoverable beats gone forever)
- When in doubt, ask.

## Git
- Default branch is always `main`
- Always branch from `main` for feature work
- Verify branch name before pushing

## Memory
- Daily logs cap at 5KB — summaries, not transcripts
- Project work logs go in project changelogs, not daily memory
- Write to memory after every significant milestone — don't wait

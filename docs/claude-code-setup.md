# Claude Code setup — configuring the assistant on a project

> Reference. Extracted from `claude-code-project-standard.md` §6, §7, §8 and from `METHODE.md` (delegation).

---

## `CLAUDE.md` — local instructions for Claude Code

File present at `repo/CLAUDE.md` but **ignored by Git**. Claude Code reads it automatically every session (it's in the cwd).

**Typical content**:
- Short project description (one line).
- Useful commands (`docker compose up`, `npm run dev`, etc.).
- Pointers into `workspace/`: where plans, docs, secrets live.
- Project-specific code conventions.
- What must absolutely not be touched (submodules, third-party code, etc.).

**What `CLAUDE.md` NEVER contains**:
- No secret, token, API key (even though it's ignored, zero-secret discipline applies to any file *named by convention* → if `.gitignore` is ever misconfigured, nothing leaks).
- No volatile value that changes every week.

A future cloner who doesn't have `workspace/` (because they only got the repo from GitHub) will work without `CLAUDE.md`, and that's intentional: the repo stays 100% impersonal.

---

## `.claude/` — project-level Claude Code config

Folder entirely **ignored by Git**. Contains:

- `settings.local.json`: permissions granted for this project, Claude-Code-specific env variables, local hooks.
- Possibly `commands/`, `agents/`, `skills/` if project-specific tools are created for Claude Code.

**Files Claude Code reads in `.claude/`**:
`settings.json`, `settings.local.json`, `commands/`, `agents/`, `skills/`, `rules/`.

**Files NOT to create in `.claude/`**:
- `launch.json` (VS Code format, ignored by Claude Code, a classic confusion).
- Any other file not on the list above.

---

## Claude Code's persistent memory

Stored by Claude Code under `~/.claude/projects/<path-hash>/memory/`, where `<path-hash>` is derived from the project's absolute path (e.g. `-Users-<user>-Documents-Claude-<project>`).

**Consequence**: renaming the project folder makes Claude Code create a **new** memory folder and lose the link to the old one.

**Rename procedure**:
1. Rename the project folder (`~/Documents/Claude/old` → `~/Documents/Claude/new`).
2. Merge the old memory folder's content into the new one:
   ```bash
   rsync -av ~/.claude/projects/-Users-<user>-Documents-Claude-old/ \
             ~/.claude/projects/-Users-<user>-Documents-Claude-new/
   rm -rf ~/.claude/projects/-Users-<user>-Documents-Claude-old/
   ```
3. Verify that `/resume` does offer the past conversations.

---

## Delegating: Claude is the orchestrator

**As soon as a task costs LESS delegated** — or it is **noticeably faster or more capable at equal cost** *(or very slightly higher)* — **Claude takes the orchestrator role and delegates** to one or more subagents.

- The subagent **does the work itself**: it does not re-delegate, and it **does not call the advisor**.
- It often runs on a **faster and cheaper** model *(Sonnet, or even Haiku)* — the orchestrator keeps the reasoning, the agent executes.
- **Prefer workflows** *(deterministic orchestration: parallel fan-out, pipeline, adversarial verification)* **as much as possible and as much as relevant**: a task that breaks down into parallel tasks or verifiable steps benefits from being a workflow rather than one long sequential pass.

The goal: the orchestrator spends its tokens **deciding**, not executing what a lighter model does just as well.

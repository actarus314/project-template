# Claude Code setup — configuring the assistant on a project

> Reference. Owns standard §6, §7, §8, and delegation (`METHODE.md`).

---

## `CLAUDE.md` — the file that makes the rules readable at all

Claude Code reads `CLAUDE.md` from the working directory at every session, and **it reads nothing else on its own**: `AGENTS.md` is loaded only because `CLAUDE.md` imports it. Measured on a clone — an agent started there reported `AGENTS.md` was **not** in its context. On disk, and invisible.

### The rule

> **`CLAUDE.md` is VERSIONED — and it carries nothing but the import.**

Both halves matter. Versioned, because a gitignored file reaches no one who clones: the rules would be read by their author alone. Nothing but the import, because everything else is what makes publishing it a risk — and a file that cannot hold anything personal does not depend on anyone remembering that it must not.

**So it contains**: `@AGENTS.md`, and at most a few impersonal lines saying why.
**It never contains**: a machine path, a personal preference, the name of a private repository, a secret of any kind, or a value that changes every week. Project commands, structure and conventions belong in `AGENTS.md` — where every agent reads them, not just Claude Code.

Anything personal goes to `~/.claude/CLAUDE.md` (that machine, all projects) or to a local settings file. `.claude/` stays gitignored: the one **documented** leak around AI tooling is `settings.local.json` carrying real credentials, never the text of `CLAUDE.md`.

This is what the ecosystem does, measured rather than assumed: of 25 public repositories examined one by one, 22 version the file, and six — Next.js and Prisma among them — reduce it to a pointer at `AGENTS.md`. *(A versioned `.example` only works where an installer performs the copy: a template nobody copies is a file nobody reads, silently.)*

**It applies from the first commit, not from the flip.** Visibility was once the trigger, which made the rule wait on a gesture nobody performs on a private project — where the file is just as invisible to whoever clones. What makes publishing safe is the *content*, never the timing.

⚠️ **A repository ADOPTED into the standard is the one case needing care**: its `CLAUDE.md` already exists, full of whatever its author put there. Read it before tracking it — machine paths, private repository names, preferences — because the history keeps whatever is pushed.

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
- 🔴 **What decides is DECOMPOSABILITY into units that do not touch each other** — never "multi-agent or not". Where sub-tasks share files or interfaces, every measured source converges on the single agent: coordinated success falls monotonically — **68,6 %** at two agents, **46,5 %** at three, **30,0 %** at four *(650 real software tasks)* — and Anthropic names CODE as its own unfavourable case. Genuinely disjoint, read-only work *(several angles of one search)* is the favourable one.
- **Prefer workflows** *(deterministic orchestration: parallel fan-out, pipeline, adversarial verification)* **wherever that condition holds**: a task that breaks down into parallel tasks or verifiable steps benefits from being a workflow rather than one long sequential pass. ⚠️ At EQUAL token budget a single agent equals or beats every multi-agent architecture tested — the gain is bought compute at ≈ **3,75×** the price, not a better architecture.

The goal: the orchestrator spends its tokens **deciding**, not executing what a lighter model does just as well.

### 🔴 The three above are OPT-INS — and `verify-delegation.sh` is what checks them

Left unwritten in the prompt, **the default does the opposite of all three, silently**. Nothing reports the omission, in either direction, which is why discipline alone never held.

`verify-delegation.sh` is a **`PreToolUse` hook** that refuses a subagent launch when the prompt omits *"does not re-delegate"* or *"does not call the advisor"*, or when the model is not a cheaper one. It **blocks** rather than warns, because nothing in it is a judgement: `model` is a field of the event, and the other two are strings that are present or absent.

**It ships inactive, and activating it is a deliberate choice.** A hook only acts once declared, so the file travels without doing anything until it is wired — appropriate, since it enforces a working method that not every project shares.

- **For one machine, every project** — in `~/.claude/settings.json` *(local, never versioned)*:
  ```json
  "hooks": { "PreToolUse": [ { "matcher": "Agent",
    "hooks": [ { "type": "command", "command": "bash <abs-path>/verify-delegation.sh" } ] } ] }
  ```
  ⚠️ The path is **absolute**: moving the folder breaks the hook, exactly like the pointer in `~/.claude/CLAUDE.md`.
- **For a plugin distribution** — a `hooks/hooks.json` beside the manifest, where `${CLAUDE_PLUGIN_ROOT}` **does** resolve: the runtime substitutes it in **configuration it reads itself** (hooks, MCP servers, monitors), **never** in a skill's own text. A skill's Markdown is read by the assistant like any other file, not templated by the runtime — a path written as `${CLAUDE_PLUGIN_ROOT}/…` inside a `SKILL.md` stays a literal, unresolved string, so the skill has to compute its own absolute path instead *(a measured failure of exactly this: [`skills/new-project/SKILL.md`](../skills/new-project/SKILL.md#step-0-resolve-the-template-root-before-reading-anything), "Step 0")*.

⚠️ **Keep the trigger narrow.** Anything that is not a subagent launch must exit at once: a guard that fires everywhere earns overrides until nobody reads it any more.

---

## What a `SKILL.md` owes — the contract, and the failure that has no error

A skill is a folder holding `SKILL.md`, plus whatever it calls. The file opens on a YAML front matter, and **`name` and `description` are two separate keys, each on its own line** — measured across 60 installed third-party skills, all of them do this and none deviates.

> 🔴 **Written on one line, `description` stops existing.** YAML reads `name: x description: y` as a single key whose value is the whole string. The skill still loads, still lists, and **never fires on the phrases it was written for** — the field carrying its triggers was never parsed. Both skills here shipped that way, and nothing reported it: no error, no warning, no missing file.

**`description` is the only thing the assistant reads before deciding to invoke** — so it states *when to use this*, with the maintainer's own wording as triggers, not what the skill does internally. That belongs to the body.

**The body then owes two things.** It **resolves its own paths**, for the reason the delegation section above already states. And it **points rather than restates**: the runbook, the standard and the method own their content, so a skill that copies a procedure becomes the stale copy the day that procedure moves.

# Project Layer <!-- omit from toc -->

Which file each AI tool reads inside a project repository,
why the files are arranged the way they are,
and how a project rule becomes enforcement instead of advice.
This is the layer underneath the personal one that
[Strategy][strategyDoc] describes;
my personal repositories get it from a shared template.

#### Table of Contents <!-- omit from toc -->

- [Layout](#layout)
- [Why AGENTS.md is the canonical file](#why-agentsmd-is-the-canonical-file)
- [Instructions and skills](#instructions-and-skills)
- [Agents come from the person](#agents-come-from-the-person)
- [Enforcement](#enforcement)
- [Plugins](#plugins)
- [Adding something](#adding-something)
- [Known limits](#known-limits)

## Layout

| File                              | Read by                      | Contains                           |
| :-------------------------------- | :--------------------------- | :--------------------------------- |
| 📄 `AGENTS.md`                     | Most tools; Claude by import | Every rule that always applies     |
| 📄 `.claude/CLAUDE.md`             | Claude Code                  | `AGENTS.md` import, Claude notes   |
| 📁 `.github/instructions/`         | Copilot (all surfaces)       | Rules scoped to one file type      |
| 📄 `.github/copilot-instructions.md` | Copilot                    | A pointer for surfaces needing one |
| 📁 `.claude/skills/`               | Claude Code, Copilot, Cursor | Procedures, loaded only when used  |
| 📄 `.claude/settings.json`         | Claude Code, VS Code         | Permission policy, hooks, plugins  |
| 📁 `docs/`                         | Humans; agents on demand     | The reasoning behind the rules     |

Which Copilot surface reads which file is tabulated in
[GitHub's own support matrix][copilotSupport];
the table above names the surfaces that matter to the arrangement.

Each rule is **stated** in exactly one of these files.
Where a second tool needs its own file, that file points at the first.

## Why AGENTS.md is the canonical file

[AGENTS.md][agents] is the cross-tool convention,
and it is the instruction file the widest set of tools read natively:

- **GitHub Copilot** reads `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md`
  directly, on every surface — the IDE, the CLI, the cloud agent,
  and code review — in addition to `copilot-instructions.md`.
- **Claude Code** reads `AGENTS.md` only when no `CLAUDE.md` exists,
  so `CLAUDE.md` stays the entry point and `@`-imports `AGENTS.md`.
  The import is expanded into context at session start —
  real transclusion, not a hint — so `CLAUDE.md` carries almost nothing
  of its own, and a personal `CLAUDE.local.md` can never hide
  `AGENTS.md` the way it would without the import.
  See [how Claude Code loads memory][claudeMemory].

`CLAUDE.md` lives in `.claude/`, the other place Claude Code looks for
it, which keeps the repository root clear and — since Copilot only reads
a root `CLAUDE.md` — means Copilot sees `AGENTS.md` once, not twice.

Instruction files must **state** each rule, not merely link to it.
Agentic tools will follow a Markdown link to `docs/`,
but code review and inline completion won't:
they get the instruction text injected and nothing more.
So the rule goes in the instruction file
and the rationale goes in `docs/`.

## Instructions and skills

Instructions say *how to write code*.
Skills say *how to do a job*.

A rule for every file goes in `AGENTS.md`.
A rule for one file type goes in `.github/instructions/`,
in a file whose front matter names the glob it applies to.
A procedure — how this project commits, releases, or resolves a
template sync — is a skill in `.claude/skills/`,
in the [Agent Skills][agentSkills] layout.
That one path is read by Claude Code, by every Copilot surface
including code review, and by Cursor,
which makes a skill the closest thing to a write-once artifact here,
and it loads lazily, so the body costs nothing until it runs.
See the [Copilot][copilotSkills] and [Claude Code][claudeSkills]
descriptions of what each loads.

A skill can opt out of automatic invocation
when it should only ever run on request.
Most are better left discoverable,
so the model can reach for one on its own.

## Agents come from the person

My projects ship no agents.
The reviewers I run before a pull request are mine —
they encode what *I* want checked, in whichever project I am in —
so they are installed from the personal harness into `~/.claude/agents`,
where Claude Code and VS Code both read them.
A project that needed its own agent would put it in `.claude/agents/`,
and that copy would take priority over mine inside that project.

Agents suit work that is **self-contained, verbose, and parallel** —
a review, and very little else.
The main conversation is the developer; design needs back-and-forth,
which is the one thing a subagent is bad at;
and Claude Code's own loop already orchestrates.
The lever that controls delegation is each agent's description.

## Enforcement

Instructions are context, not enforcement.
Three mechanisms hold a project rule every time, and each has a job:

- **Repository rulesets** are the backstop.
  They hold regardless of which tool, person, or agent is pushing,
  so anything about the default branch, review, or required checks
  is a ruleset first and a Markdown rule second.
- **Hooks** run a script at a point in the agent's loop
  and can block the action.
  The ones that bind every contributor live in the project's
  `.claude/settings.json`, with their scripts beside it,
  written so one script runs on every operating system.
  See [how Claude Code hooks work][claudeHooks]
  and [Copilot's own hook format][copilotHooks],
  which gets a mirror only for a check that matters there.
- **Permission policy** — what an agent may do without asking,
  what it must ask about, what it may never do —
  also lives in the project's `.claude/settings.json`.
  The deny and ask lists are the shared part;
  the allow list is kept short, because every entry is a judgement
  made for everyone.
  See [how settings are layered][claudeSettings].

A hook is a program, so it is tested like one.

## Plugins

Capability written by someone else arrives as a **plugin**,
not as copied files, so it can be updated, pinned, and removed.
A project declares the marketplaces and plugins it expects in
`.claude/settings.json`; a contributor still accepts the marketplace
and installs the plugin once, and the declaration tells them which.
A third-party plugin is pinned to a commit,
because third-party marketplaces are not updated automatically
and a moving branch is not a version;
see [how a plugin source is resolved][claudePluginLoading].

A plugin **cannot** carry a project's instructions, its permission
policy, or its sandbox settings
(see [what a plugin may contain][claudePluginComponents]);
those stay in the project.
A skill is copied into `.claude/skills/` instead of installed
only when it must reach a surface that does not read plugins,
such as Copilot code review,
and the copy records where it came from and which commit.
How a source is judged before any of this happens is the subject of
[Sources][sourcesDoc].

## Adding something

Everything is **additive**:
a template layer contributes its own file and never edits an inherited
one, so template merges stay clean.

- **A file type:** one file in `.github/instructions/`,
  named `<type>.instructions.md`, with an `applyTo` glob and a
  description in its front matter.
  A .NET template adds one for C#; the base carries only the types every
  project has.
- **A skill:** one folder in `.claude/skills/`,
  owned by the layer that owns the language or the procedure.
- **A plugin:** judged first, then declared in the `.claude/settings.json`
  of the layer whose projects all need it, pinned.
- **A tool:** most read `AGENTS.md`, so there is nothing to do.
  For one that doesn't, add the file it does read, whose entire content
  points at `AGENTS.md` — never a copy of the rules.

## Known limits

- **Front matter globs are Copilot's mechanism.**
  Claude Code's equivalent is a `.claude/rules/` file with a `paths`
  list. Using it would mean a second small file per file type,
  so instead `AGENTS.md` tells agents to read the matching instruction
  file themselves — reliable in practice, but discretionary.
- **`.claude/skills/` is not read by every tool.**
  Some read `.agents/skills/` instead;
  Claude Code [does not read that path][claudeAgentsSkillsIssue].
  A project that must serve such a tool adds per-skill links,
  never a link to the whole folder.
- **`applyTo` on github.com** applies to Copilot code review
  and the cloud agent. In the IDE it applies everywhere.
- **A declared plugin is not an installed plugin.**
  The project can only say what it expects; a person completes it.
- **The Copilot cloud agent sees no reviewers.**
  It reads only a project's own `.github/agents/`,
  and my reviewers are personal.
  Review on github.com comes from Copilot code review and the other
  reviewers described in [Autonomy][autonomyDoc] instead.

<!-- Repository files -->

[autonomyDoc]: ./Autonomy.md
[sourcesDoc]: ./Sources.md
[strategyDoc]: ./Strategy.md

<!-- Other repositories -->

[claudeAgentsSkillsIssue]: https://github.com/anthropics/claude-code/issues/31005

<!-- Public websites -->

[agentSkills]: https://agentskills.io/specification
[agents]: https://agents.md
[claudeHooks]: https://code.claude.com/docs/en/hooks
[claudeMemory]: https://code.claude.com/docs/en/memory
[claudePluginComponents]: https://code.claude.com/docs/en/plugins/components
[claudePluginLoading]: https://code.claude.com/docs/en/plugins/loading
[claudeSettings]: https://code.claude.com/docs/en/settings
[claudeSkills]: https://code.claude.com/docs/en/skills
[copilotHooks]: https://docs.github.com/en/copilot/reference/hooks-configuration
[copilotSkills]: https://code.visualstudio.com/docs/agent-customization/agent-skills
[copilotSupport]: https://docs.github.com/en/copilot/reference/custom-instructions-support

# AI Harness <!-- omit from toc -->

My personal way of working with AI coding agents:
the Claude Code and GitHub Copilot files I prefer at user level,
and the scripts that install and keep them current on any machine.

Nothing here belongs to any one project or employer.
A repository's own instruction files always win over these;
this is the layer underneath them.

#### Table of Contents <!-- omit from toc -->

- [How it works](#how-it-works)
  - [Linked or generated](#linked-or-generated)
  - [The local overlay](#the-local-overlay)
- [Layout](#layout)
- [Installing](#installing)
- [Day to day](#day-to-day)
- [Updating](#updating)
- [Plugins and MCP servers](#plugins-and-mcp-servers)
- [Checking the installation](#checking-the-installation)

## How it works

Claude Code and Copilot both assemble their instructions from several
places at once: the person's own user-level files, then any files in the
folders above the repository, then the repository's own.
The more specific file wins where two disagree.
This repository is the source of the **user-level** layer —
the files that would otherwise live loose in `~/.claude/` and
`~/.copilot/` on every machine, drifting apart.

Install it once per machine and the same preferences, skills, agents,
and hooks are in place everywhere, under version control,
with the repository's history as the record of what changed and why.
[Strategy][strategyDoc] explains where each kind of rule lives across
the whole arrangement and why; [Playbooks][playbooksDoc] has the
step-by-step procedures; the rest of [docs/](./docs/) goes deeper.

### Linked or generated

Each item is installed in one of two ways,
chosen by whether the tool ever writes to it:

- **Linked.** Folders the tools only read — skills, agents, hooks —
  are symbolic links into this checkout.
  Editing a skill in `~/.claude/skills/` edits the repository;
  commit when it is right.
  Skills are linked into every folder the tools look in,
  so one copy serves Claude Code, Copilot, and anything else that reads
  the [Agent Skills][agentSkills] layout.
- **Generated.** Files a tool writes to on its own, or that need a
  machine-specific fragment spliced in, are rendered as plain copies:
  `settings.json`, because Claude Code records approvals into it,
  and the instruction files, because each gets a local fragment appended
  and the same text is written for both tools.
  Every generated file starts with a comment saying so,
  and the installer backs up any hand-made file it would replace.

### The local overlay

Some facts are true on one machine only, or name an account:
which sign-in works under which folder, a proxy that blocks a host,
where the personal repositories live.
Those never belong in a public repository.

They go in `local/`, a folder inside the checkout that git ignores —
the **machine** layer, under the user layer the rest of the repository is.
The installer merges whatever it finds there:
a `CLAUDE.md` fragment is appended to the generated user-level
instructions; a `Personal.CLAUDE.md` or `Work.CLAUDE.md` fragment is
appended to that folder's generated file, which is where an account name
lives; a `settings.json` fragment is deep-merged into the generated
settings; and `harness.json` holds the paths the manifest refers to as
tokens.
[local.example/](./local.example/) shows the shape of each.
On a new machine the installer asks for anything it needs
and writes the answers there, so nothing is placed by hand.

## Layout

```text
📁 claude/            source of the ~/.claude user-level files
   📄 CLAUDE.md       how I work — rendered for Claude Code and for Copilot
   📄 settings.json   model, permissions, local hooks, plugin list
   📄 plugins.json    plugins to install, pinned
   📄 mcp.json        MCP servers to register at user scope
   📄 notifications.json  which sound and toast for which event; read live
   📁 skills/         linked into every skills folder the tools read
   📁 agents/         personal agents
   📁 hooks/          scripts the hooks call — local only, nothing leaves the machine
📁 contexts/          CLAUDE.md files for the folders that hold groups of repositories
   📄 Personal.CLAUDE.md  installed above my personal repositories
   📄 Work.CLAUDE.md      installed above my work repositories, on a machine that has any
📁 docs/              strategy, the project layer, playbooks, autonomy, external sources
📁 local/             this machine only — where the folders are, which accounts, what is blocked; git-ignored
📁 local.example/     the shape of each local file
📁 scripts/           install, update, and test
📄 harness.json       the manifest: what is linked where, what is generated from what
```

## Installing

Needs PowerShell 7.4 or later, git, and — for plugins and MCP servers —
the Claude Code CLI on the path.
On Windows, symbolic links need Developer Mode or an elevated shell.

```powershell
git clone https://github.com/TaffarelJr/ai-harness.git
cd ai-harness
./scripts/Install-Harness.ps1
```

The first run asks where the personal repositories live
and remembers the answer in `local/harness.json`.
A machine that also holds work repositories gets `-WorkRoot` once;
it is never asked for, because most machines have none.
Add `-WhatIf` to see every link and file it would create without
creating any.
Add `-SkipPlugins` or `-SkipMcp` to leave those steps for later,
and `-NonInteractive` when nothing may prompt.

Anything the installer replaces is renamed beside itself
with a `.harness-backup-<timestamp>` suffix, never deleted.
It checks every manifest first, and a key it does not recognize stops it
before it changes anything — the message names the key and the ones it
would accept.

## Day to day

Nothing. The linked folders are live:
edit a skill or an agent in place, and the change is in the checkout,
waiting to be committed.
For the generated files, edit the **source** in `claude/` or `local/`
and run the installer again; editing the generated copy is undone by the
next install, and the updater tells you when that is about to happen.

Which sound plays for which event, how often, and whether a toast
appears is set in `claude/notifications.json`, with this machine's own
choices in `local/notifications.json`; the hook reads both every time,
so a change is live at once, and comments are allowed in both.

## Updating

```powershell
./scripts/Update-Harness.ps1
```

Pulls the repository, reinstalls, updates the listed plugins,
and prints a **drift report**: what changed in a generated file since it
was generated — typically approvals Claude Code saved into
`settings.json`.
Each entry is either promoted into `claude/settings.json`
(or `local/settings.json`, if it is machine-specific)
or dropped by the reinstall.

## Plugins and MCP servers

`claude/plugins.json` lists the marketplaces and plugins installed at
user scope; `claude/mcp.json` lists MCP servers registered at user scope.
A server that exists on one machine only goes in `local/mcp.json`,
in the same shape; it is added to the shared list, and wins on a name clash.
The installer adds what is missing and the updater brings it current,
so a new machine needs no remembered install commands.
The settings keys that record which plugins are enabled are generated
from the same manifest, so an install never shows up as drift.
Third-party marketplaces are pinned to a commit in the manifest,
because they do not update themselves and a branch is not a version.

A server's secrets are never in the manifest.
The configuration refers to environment variables,
and their values are set on the machine.

## Checking the installation

```powershell
./scripts/Test-Harness.ps1 -Installed
```

Confirms every link points into the checkout,
every generated file is the one the installer wrote,
and every script and manifest parses.
Without `-Installed` it checks only the repository itself,
which is what a change should pass before it is committed.

<!-- Source Code URIs (folders first, then files; each alphabetical) -->

[playbooksDoc]: ./docs/Playbooks.md
[strategyDoc]: ./docs/Strategy.md

<!-- Public URIs (alphabetical) -->

[agentSkills]: https://agentskills.io/specification

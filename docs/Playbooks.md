# Playbooks <!-- omit from toc -->

The recurring procedures, step by step: bringing something new in,
changing the harness while using it, deciding what Claude's own edits to
`settings.json` deserve to keep, moving changes between machines, and
recovering when something goes wrong.
[Strategy][strategyDoc] says why things are arranged this way;
this document says what to do.

#### Table of Contents <!-- omit from toc -->

- [Evaluating something found online](#evaluating-something-found-online)
- [Adding something after evaluation](#adding-something-after-evaluation)
- [Changing the harness while working](#changing-the-harness-while-working)
- [Reconciling Claude's edits to settings.json](#reconciling-claudes-edits-to-settingsjson)
- [Syncing between machines](#syncing-between-machines)
- [Setting up a new machine](#setting-up-a-new-machine)
- [Loosening a guardrail for one session](#loosening-a-guardrail-for-one-session)
- [Undoing an install](#undoing-an-install)
- [Knowing what is installed](#knowing-what-is-installed)

## Evaluating something found online

1. Read it against the rubric in [Sources][sourcesDoc], in order;
   a bad answer early ends the read.
2. If it installs itself, try it somewhere disposable first.
   Claude Code keeps all of its state under the folder named by
   `CLAUDE_CONFIG_DIR`, so a scratch folder is a clean room:

   ```powershell
   $env:CLAUDE_CONFIG_DIR = '<an empty folder>'
   claude                                # sign in, install, try it
   Remove-Item Env:CLAUDE_CONFIG_DIR     # back to the real config
   ```

   Nothing it wrote reaches your real configuration;
   delete the folder when done.
3. Write the verdict — one of the words in [Sources][sourcesDoc] —
   as a row or comment on the current *AI sources review* issue
   in this repository, with the one-line reason.
   A **Trial** gets its success criterion written there *before* it starts.
4. Only then do anything from the next section.

## Adding something after evaluation

Every kind has one home and one way in.
After any change below, run `./scripts/Test-Harness.ps1`
before committing; it parses every manifest and script.

| Kind | Where it goes | Then |
| :-- | :-- | :-- |
| Plugin for you, every project | An entry under `Plugins` in `claude/plugins.json`; a third-party marketplace also gets a `Marketplaces` entry pinned with `Source: "owner/repo#<commit>"` | `./scripts/Install-Harness.ps1` installs it and regenerates `settings.json` |
| Plugin a project needs | That project's `.claude/settings.json`, not the harness; see [Project Layer][projectLayerDoc] | — |
| Skill | A folder under `claude/skills/<name>/` with a `SKILL.md`; the `skill-creator` plugin writes a good one. A **vendored** skill records its origin and commit in its front matter | Live for new sessions at once — the folder is linked |
| Agent | `claude/agents/<name>.md` | Live for new sessions at once |
| Always-on instruction | A line in `claude/CLAUDE.md`; a **Cherry-pick** becomes a line here, in your words | `Install-Harness` regenerates both tools' files |
| Machine-only instruction | `local/CLAUDE.md` (git-ignored) | `Install-Harness` |
| Folder context (a group of repositories) | `contexts/<Name>.CLAUDE.md` for what is true of the group, an `Instructions` entry in `harness.json` with a root token, and a `local/<Name>.CLAUDE.md` fragment for the names only that machine knows | `Install-Harness` |
| Hook | A script in `claude/hooks/` and an entry in `claude/settings.json` whose command uses the `{{hooks}}` token | `Install-Harness`, then a new session |
| MCP server for you | A block under `mcpServers` in `claude/mcp.json`, in the same shape as a project's `.mcp.json`, or in `local/mcp.json` (git-ignored) for a server only this machine has; any secret is an environment-variable reference, and the value is set on the machine, never in a file | `Install-Harness` registers it at user scope |
| PowerShell module a hook needs | An entry under `PowerShellModules` in `harness.json` | `Install-Harness` |

Commit on a branch, open a pull request, and if the change is several
pull requests, link them into a stack.

## Changing the harness while working

The harness is live while Claude runs, which is convenient and worth
understanding:

- **Linked folders** (`skills/`, `agents/`, `hooks/`) are the checkout
  itself. An edit is in place the moment it is saved; a new session sees
  it. Editing a skill mid-task and invoking it again is fine.
- **Generated files** (`CLAUDE.md`, `settings.json`) only change when
  `Install-Harness` runs, and Claude Code reads settings and hook
  configuration when a session starts. So: edit the source, run
  `./scripts/Install-Harness.ps1`, start a new session.
- **Do not edit the generated copies.** The next install replaces them
  and tells you so (and backs them up first). For a one-off experiment
  in one project, use that project's git-ignored `CLAUDE.local.md`
  or `.claude/settings.local.json` instead.

The comfortable setup is a second VS Code window on the harness
checkout: edit and test there (`Test-Harness.ps1`, or run a hook by hand
with a sample JSON on standard input), commit on a branch, and keep
working in the first window. A hook edit is the one case to pause for:
the running session uses the hook file as it is on disk, so save a hook
only in a state that parses.

## Reconciling Claude's edits to settings.json

Claude Code writes into the user `settings.json` on its own — most often
an approval you clicked "always allow" on, which lands as a new
`permissions.allow` entry. The generated copy therefore drifts from
what the installer wrote. Nothing is lost: the installer keeps a sidecar
of exactly what it generated, and compares.

1. Run `./scripts/Update-Harness.ps1` (or `Install-Harness.ps1`;
   both report, Update also pulls first).
   The **drift report** lists each JSON path added, removed, or changed
   since the last install.
2. Decide per entry:
   - **Keep for every machine** → add it to `claude/settings.json`.
     An approval you would want at home too belongs here.
   - **Keep for this machine only** → add it to `local/settings.json`.
     Anything naming a work server, a local folder, or this machine's
     MCP servers belongs here.
   - **Drop** → do nothing. A rule containing a temp path, a session id,
     or one specific file name was a one-off; it dies with the reinstall.
3. Run `./scripts/Install-Harness.ps1`. It backs up the drifted file
   beside itself, regenerates from source plus local, and the kept
   entries are now permanent while the dropped ones are gone.
4. Commit the change to `claude/settings.json`, if any.

`./scripts/Test-Harness.ps1 -Installed` warns `drift` whenever the
generated copy differs from its sidecar, so a quick check at any time
tells you whether this step is due.

## Syncing between machines

The repository is the channel; `local/` never travels.

**Pushing a change up:** commit on a branch in the harness checkout,
open a pull request, let it be reviewed, merge. The checkout you edited
in is already installed, so nothing else happens on that machine.

**Pulling changes down** on another machine:

```powershell
./scripts/Update-Harness.ps1
```

It fast-forwards the checkout (`git pull --ff-only`), reinstalls
(links are idempotent, generated files are re-rendered), brings the
listed plugins and PowerShell modules current, and ends with the drift
report above. If you had committed locally on that machine and the pull
cannot fast-forward, it stops and says so; rebase the local branch and
run it again. `-SkipPull` runs everything except the pull.

Finish with `./scripts/Test-Harness.ps1 -Installed`: every link resolves
into the checkout and every generated file is the one just written.

## Setting up a new machine

1. Install PowerShell 7.4 or later, git, and the Claude Code CLI; sign
   the CLI in with the account that machine should use.
2. Clone this repository anywhere permanent (not a temporary folder —
   the links point into it).
3. Create `local/` from the samples in `local.example/`: `harness.json`
   is written for you on the first run, the others are optional and
   hold whatever is true only on that machine.
4. `./scripts/Install-Harness.ps1 -WhatIf` to read what will happen,
   then without `-WhatIf`. It asks once where the personal repositories
   live and remembers the answer in `local/harness.json`.
   If the machine also holds work repositories, pass `-WorkRoot` once;
   it is remembered the same way and never asked for.
5. `./scripts/Test-Harness.ps1 -Installed`.

On Windows, directory links are junctions, so no Developer Mode or
elevation is needed. The first install on a machine that already had a
hand-made `~/.claude/CLAUDE.md` or `settings.json` backs each one up
beside itself; read the backup for anything worth promoting into
`claude/` or `local/`, then delete it.

## Loosening a guardrail for one session

- **History rewrite** (force-pushing or deleting `main`/`master`,
  resetting a repository): set `AI_HARNESS_ALLOW_HISTORY_REWRITE=1` in
  the shell, start Claude from that shell, do the work, close the
  session. The hook reads the variable only from its own environment,
  so nothing Claude runs can set it, and merging a pull request stays
  denied regardless.
- **Silence** (a call, a recording): `"Quiet": true` in
  `local/notifications.json`. It is read on the next notification —
  no restart — and the log line is still written.
- Anything you do in your **own terminal** is never governed by the
  hooks; they see only the commands Claude runs.

## Undoing an install

Nothing is ever deleted. Each replaced item is renamed beside itself
with a `.harness-backup-<timestamp>` suffix, so undoing is renaming back:

1. Remove the links the installer made (`Remove-Item` on a junction or
   symlink removes the link, not what it points to).
2. Rename the newest `*.harness-backup-*` of each generated file back to
   its original name, or delete the generated file to start clean.
3. Plugins and MCP servers registered through the manifests are removed
   with `claude plugin uninstall` and `claude mcp remove`.

The checkout itself is just a repository; leave it or delete it.

## Knowing what is installed

There is no inventory to maintain; ask the sources of truth:

- `./scripts/Test-Harness.ps1 -Installed` — every link, generated file,
  and module, with any drift.
- `claude plugin list` and `claude mcp list` — what Claude Code itself
  has, which should match `claude/plugins.json` and `claude/mcp.json`
  plus whatever `local/` adds.
- `git -C <checkout> status` — anything edited in a linked folder and
  not yet committed.
- `~/.claude/notifications.log` — what the notification hook has fired
  for, when, and in which folder.

<!-- Source Code URIs (folders first, then files; each alphabetical) -->

[projectLayerDoc]: ./ProjectLayer.md
[sourcesDoc]: ./Sources.md
[strategyDoc]: ./Strategy.md

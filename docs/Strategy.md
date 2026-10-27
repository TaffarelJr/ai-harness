# Strategy <!-- omit from toc -->

One way of working with AI coding agents, carried across two tools,
several machines, and every repository I touch —
without a rule ever being written twice,
and without my preferences leaking into anyone else's work.

#### Table of Contents <!-- omit from toc -->

- [Three layers, loaded together](#three-layers-loaded-together)
- [Who a rule binds decides where it lives](#who-a-rule-binds-decides-where-it-lives)
  - [Preferences are not rules](#preferences-are-not-rules)
  - [Work and personal](#work-and-personal)
- [What is mine and what is a project's](#what-is-mine-and-what-is-a-projects)
- [Two tools, one source](#two-tools-one-source)
- [Enforcement](#enforcement)
- [Everything else](#everything-else)

## Three layers, loaded together

Neither Claude Code nor Copilot picks one instruction file.
Each stacks several, from the least specific to the most,
and reads them all:

```text
~/.claude/CLAUDE.md                    my way of working — this repository
<personal>/CLAUDE.md                   the folder that holds a group of repositories
<personal>/some-repo/CLAUDE.md         the repository itself, importing its AGENTS.md
<personal>/some-repo/CLAUDE.local.md   my private notes about that one repository
```

`<personal>` is wherever that machine keeps my personal repositories;
the installer asks once and remembers the answer in `local/`.
A machine with work repositories has a `<work>` folder too,
with its own `CLAUDE.md` from the same mechanism.
Anything nested below either folder inherits its file,
so one folder per context is enough.

Settings stack the same way, from the user's file through the
repository's to a git-ignored local one; a later file overrides a value,
lists are merged, and a denial always beats an allowance.
Skills and agents are discovered from the user's folders,
the repository's folders, and installed plugins, all at once.

So **precedence is automatic**: the repository's rule is the more
specific one and wins when the two disagree.
The one thing the personal layer must say out loud is that it defers —
and it does, in its first paragraph.

This repository is the versioned source of the top layer.
[Project Layer][projectLayerDoc] describes the bottom one.

## Who a rule binds decides where it lives

Not which tool reads it, and not how important it feels.

- **One person, on their own machines** —
  how I like output phrased, which models I default to,
  the hooks that stop me doing something I'd regret,
  the skills and agents I reach for.
  Here, in `claude/` and `copilot/`.
- **One person, across a group of repositories** —
  everything under one folder is public open source and tracked on
  GitHub; everything under another belongs to an employer, is planned
  in one system and built in another, and never leaves the machine.
  A `CLAUDE.md` in that folder, installed from `contexts/`;
  it binds every repository below it and lives in none of them.
  It names *kinds* of things — the tracker, the host, the fallback —
  never an account.
- **One person, on one machine** —
  where the folders are, which account each folder uses,
  which MCP servers exist here, a proxy that blocks a host.
  In `local/`, which git ignores: the machine layer.
  An account name appears only in a `local/` fragment,
  appended to the folder file it belongs to.
- **Every contributor to a project** —
  in that project's own files, or in the template it derives from.
  Never here.
- **One person, in one project** —
  an experiment, a local override.
  `CLAUDE.local.md` and `.claude/settings.local.json`,
  git-ignored by the project.

### Preferences are not rules

Everything committed to a public project binds strangers.
Before a line goes into a project, the test is whether I would hand it
to a first-time contributor as a condition of merging.
If I would not, it is a preference, and it belongs here.
A preference that reaches a project becomes a rule nobody agreed to,
and it is the first thing a contributor's own agent will fight.

### Work and personal

Nothing that belongs to an employer is in this repository.
Work rules live in work repositories and in the employer's own base
repository, where they are the more specific layer and therefore win.
What I carry into a work repository from here is **style** — how I
like a diff shaped, how I like progress reported, what I never want an
agent to do on my behalf — plus one generic folder file,
`contexts/Work.CLAUDE.md`, that says how *I* work there:
planning lives in one system and code in another,
prefer the MCP servers and fall back to the CLI when they fail,
nothing leaves the machine, only a person merges.
The specifics that make a work laptop different — which sign-in each
folder uses, which MCP servers are registered, what the proxy blocks —
are in `local/` on that machine and nowhere else.

The result is one personal layer installed on every machine,
the projects' own layers underneath it,
and a per-machine overlay for the facts that differ.
There is no second harness to maintain.

## What is mine and what is a project's

The question comes up most for skills and agents, and the answer is the
same test: who does it bind, and what is it paired with.

- A skill that defines how *this project* does something —
  how it commits, how it releases, how it resolves a template sync —
  is the project's and lives there, so every contributor's agent runs
  the same procedure.
- A skill or agent that defines how *I* work —
  how I plan, how I delegate, how I want a review structured —
  is mine and lives here.
  Reviewer agents are the clearest case: they encode what I want
  checked before I open a pull request, whichever project I am in.
- Things that work as a pair stay together.
  A project skill that dispatches a set of agents needs those agents
  in the project; a personal skill that does so needs them here.

Most procedures should be skills anyway: they load only when used,
and every tool reads them.
An agent earns its place when the work is isolated, verbose,
and parallel — reviews, mostly.
A team of agents is a set of **sessions**, each with its own job and
branch, meeting on GitHub — not a set of agents inside one session.
[Autonomy][autonomyDoc] describes that shape.

## Two tools, one source

Claude Code is the primary tool; Copilot the second opinion.
Both read the same project files — `AGENTS.md`, the path-scoped
instruction files, and the skills folder — so a project rule is written
once.
Both read the same personal files too:
the installer renders one `CLAUDE.md` for both and links one skills
folder into every place either tool looks.
Where a surface reads only its own format, that file is a thin pointer
to the shared one, never a copy of the rules.

Claude Code runs in the terminal inside VS Code for anything long,
voiced, or in the background, and in its VS Code panel when the work is
mostly reading diffs.
Copilot runs in its own panel and, as a CLI, as a second reviewer with a
model from a different vendor — the cheapest way to get a genuinely
different pair of eyes on a change.

## Enforcement

Instructions are context.
A model that has read a rule will usually follow it;
a rule that must hold *every* time needs a mechanism:

- **Personal guardrails** are hooks installed from here:
  scripts that refuse a force-push, a self-merge, the deletion of a
  default branch.
  They run locally and send nothing anywhere.
- **Project guarantees** are the project's rulesets and its own hooks.
- A denial in either layer beats an allowance in the other.

A hook that sends data off the machine is a different kind of thing.
None ships here; whether one ever does is a decision about where the
machine is allowed to talk, not about the harness.

## Everything else

- The step-by-step procedures — evaluating and adding something,
  changing the harness while working, reconciling Claude's own edits,
  syncing machines, undoing: [Playbooks][playbooksDoc].
- How material published by other people is judged, pinned, and
  retired: [Sources][sourcesDoc].
- How agents will work without a person present, when that is allowed,
  and what of that shape is already in place: [Autonomy][autonomyDoc].
- Which file each tool reads inside a project, and why:
  [Project Layer][projectLayerDoc].
- How this repository is installed and kept current: the [README][readme].

<!-- Repository files -->

[autonomyDoc]: ./Autonomy.md
[playbooksDoc]: ./Playbooks.md
[projectLayerDoc]: ./ProjectLayer.md
[sourcesDoc]: ./Sources.md
[readme]: ../README.md

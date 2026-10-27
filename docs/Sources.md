# Sources <!-- omit from toc -->

How skills, agents, hooks, and plugins published by other people
are judged, brought in, pinned, kept current, and retired —
and where the verdicts are written down so the next review
starts from the last one.

#### Table of Contents <!-- omit from toc -->

- [Why a method](#why-a-method)
- [The rubric](#the-rubric)
- [Verdicts](#verdicts)
- [Bringing one in](#bringing-one-in)
- [Knowing what is installed](#knowing-what-is-installed)
- [Keeping current](#keeping-current)
- [Retiring one](#retiring-one)

## Why a method

The supply of published agent material is large and growing faster
than anyone can read it, its quality is unrelated to its popularity,
and much of it is designed to install itself:
an installer that writes into your user configuration,
a hook that runs on every prompt, a skill that rewrites your instruction
files to suit itself.
Some of it routes a subscription through a third party in a way the
provider's terms forbid.

A method turns "this looks useful" into a decision that can be
explained, reversed, and repeated by an agent on a schedule.
Without one, the configuration becomes a sediment of things that seemed
like a good idea, and nobody can say what any layer does.

## The rubric

Every candidate is read against the same questions, in this order,
and a bad answer early ends the read:

1. **What is it, really?**
   A set of skills, a workflow framework, an orchestrator, a proxy,
   an inference engine, a research artifact.
   The category decides whether it is even in scope for an end user of
   Claude Code or Copilot, or is for people building their own agent.
2. **Who maintains it, and under what license?**
   A missing license file means the text cannot be copied,
   whatever the README says.
   A single maintainer and a release cadence of breaking changes is a
   cost to budget for, not a reason to refuse.
3. **What format is it in?**
   Material in the [Agent Skills][agentSkills] format,
   or packaged for a plugin marketplace, installs cleanly and uninstalls
   cleanly. Anything else is a copy, and copies rot.
4. **What does it write, and where?**
   Into the project, into your user configuration, into hooks that run
   on every turn, into your instruction files.
   An installer that cannot be told where to put things is run once in
   a throwaway directory to find out.
5. **Which tools read it?**
   Claude Code only, every Copilot surface, the whole standard.
   This decides whether a plugin install is enough or whether a copy is
   needed for a surface that reads only files.
6. **Does it comply?**
   Telemetry on by default, credentials stored, a subscription proxied —
   each is checked against the provider's own
   [legal and compliance][claudeLegal] terms, and a proxy that stores
   subscription tokens is refused regardless of what it saves.
7. **What does it overlap?**
   Against what is already installed and against the tool's built-in
   features. The strongest option per theme wins;
   the others are not kept "as well".
8. **Does it fight the rules?**
   A mandatory workflow that merges locally fights a project where only
   people merge. A terse-output rule fights a project whose pull request
   descriptions are read by people. The fight is weighed, not assumed
   fatal.
9. **What is the claim, and who measured it?**
   A self-reported saving is a hypothesis.
   The trial below is where it becomes a result.

## Verdicts

A candidate gets exactly one of these words,
so that a later review can see what was decided without re-reading the
reasoning:

- **Adopt** — install as a plugin, at the scope its audience needs.
- **Vendor** — copy the files in, recording source and commit,
  because a surface that must read them does not read plugins.
- **Cherry-pick** — take the idea, not the text, and fold it into
  our own instruction files in our own words.
  The only verdict available when the license is missing.
- **Trial** — adopt in one place, for a fixed period,
  against a stated success criterion written down before the trial
  starts. A trial with no criterion is an adoption that forgot to
  decide.
- **Watch** — not now; name the condition that would change the answer.
- **Skip** — and say why in one line, so the question is not re-asked.

## Bringing one in

- A plugin for me alone goes in [claude/plugins.json][pluginsManifest],
  at user scope, and is never declared in a project.
- A plugin every contributor of a project needs is **declared** in that
  project's `.claude/settings.json`, at the template layer whose
  descendants all need it; [Project Layer][projectLayerDoc] explains the
  split.
- A third-party source is **pinned** to a commit when declared.
  Third-party marketplaces are not updated automatically,
  and a branch name is not a version;
  see [how plugin sources resolve][claudePluginLoading].
- Anything installed by a script is installed into a boundary first —
  a container or a throwaway directory — and its footprint read before
  the real install.
- A vendored copy carries its origin and commit in its front matter.
  A copy without them cannot be refreshed and will not be.

## Knowing what is installed

There is no inventory document, because an inventory is a copy of the
truth and drifts from it. The truth is in the places that make the
installs happen:

- this repository's manifests and the plugin tool's own listing,
  for what I have;
- each project's `.claude/settings.json`, for what that project
  declares;
- the skills folders, for what is vendored,
  each file naming its own origin.

"What do I have" is therefore answered by this repository,
and installed on a new machine by its one script.

## Keeping current

The review that produced a verdict is re-run on a fixed cadence,
and additionally whenever a tool ships a change that could alter an
answer — a new discovery path, a new permission mode,
a built-in feature that makes a plugin redundant.
The review is a skill, run by an agent, and it:

1. updates the tools and the plugins installed from official
   marketplaces, and reports what changed;
2. checks every pinned third-party source for commits since the pin,
   and reads the changelog before moving the pin;
3. scans the places new material appears —
   the [Agent Skills showcase][agentSkills],
   the [official Claude plugin marketplace][claudePluginsOfficial],
   the [Copilot community collection][awesomeCopilot] —
   and applies the rubric to anything new that is in scope;
4. re-checks every **Watch** against its stated condition
   and every **Trial** against its criterion;
5. opens one issue in this repository with the round's findings,
   titled so the rounds list together.

Verdicts live in those issues, not in this document.
A document that listed them would be an inventory,
and the section above explains why there isn't one.

## Retiring one

A plugin is removed from the manifest and uninstalled.
A vendored copy is deleted.
A cherry-picked idea stays, because it is in our words now and was never
the source's to take back.
The round's issue records the retirement and the reason,
so the next round does not re-adopt it.

<!-- Repository files -->

[pluginsManifest]: ../claude/plugins.json
[projectLayerDoc]: ./ProjectLayer.md

<!-- Other repositories -->

[awesomeCopilot]: https://github.com/github/awesome-copilot
[claudePluginsOfficial]: https://github.com/anthropics/claude-plugins-official

<!-- Public websites -->

[agentSkills]: https://agentskills.io/specification
[claudeLegal]: https://code.claude.com/docs/en/legal-and-compliance
[claudePluginLoading]: https://code.claude.com/docs/en/plugins/loading

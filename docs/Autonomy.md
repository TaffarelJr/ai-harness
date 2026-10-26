# Autonomy <!-- omit from toc -->

How agents will work without a person at the keyboard:
where a run lives, how it is kept from stalling or doing harm,
how it asks a question instead of waiting for an answer,
and how a person hears about it and replies from wherever they are.

Most of this is **direction, not installation**.
Unattended runs need a machine that is allowed to run them and,
for anything that reaches a phone, a channel that is allowed to carry
data off the machine.
Where that permission is not yet given, what this harness installs today
is the part that needs none of it:
hooks that block a dangerous command and hooks that raise a *local*
notification, and the review arrangement in the last section,
which already runs on every pull request.

#### Table of Contents <!-- omit from toc -->

- [The shape](#the-shape)
- [Three lanes](#three-lanes)
- [Permissions without a person](#permissions-without-a-person)
- [Asking instead of stalling](#asking-instead-of-stalling)
- [Hearing about it](#hearing-about-it)
- [Dictation](#dictation)
- [Review by more than one model](#review-by-more-than-one-model)
- [Identity](#identity)

## The shape

A team of agents is a set of **sessions**, not a set of subagents.
Each session has one job, its own branch in its own worktree,
and no shared memory with the others except the repository itself.
Work enters as an issue and leaves as a pull request that a person
merges.
The issue is the brief, the pull request thread is the conversation,
and the repository's rulesets are the limits nobody can talk their way
past.

That shape is chosen over an orchestrator process because it needs
nothing that is not already there:
GitHub is the queue, the inbox, and the audit log,
and every tool involved already knows how to use it.
It also degrades gracefully.
A session that dies leaves a branch, not a half-written database.

## Three lanes

A run lives in one of three places,
and the choice is made by what the machine at hand can keep safe.

- **A local session, headless.**
  Started by a script, one per task, each in its own worktree,
  writing its result to a file the script forwards.
  Fastest to set up and the only lane that can use a tool installed on
  this machine alone.
  Unsafe on any host without a sandbox, so on a Windows machine this
  lane runs inside WSL2 or a container, never on the host itself.
  See [headless mode][claudeHeadless] and
  [background sessions][claudeAgentView], which outlive the terminal
  but not a restart.
- **A hosted session.**
  Started from the phone or the CLI and run in the provider's own
  sandbox, with no local machine involved after the start.
  The right lane for a task begun away from the desk,
  and for anything on a schedule that must fire whether or not a laptop
  is awake.
  See [cloud sessions][claudeCloud] and
  [scheduled tasks][claudeScheduled].
- **A GitHub Actions run.**
  Triggered by a mention on an issue or pull request, or by a schedule,
  with the runner as the sandbox and the repository's secrets as the
  only credentials.
  The right lane for an issue-driven loop on a public repository,
  because every step of it is already visible there.
  See the [Claude Code action][claudeGitHubActions]
  and the [Copilot cloud agent][copilotCloudAgent],
  which fills the same lane with a different model.

The lanes are not exclusive.
A hosted session can open the pull request that an Actions run reviews
and a local session fixes.

## Permissions without a person

An unattended run that asks a question has already failed:
nobody is there, and the run blocks until morning.
So every lane is configured so that a permission prompt
**cannot happen**, and the safety that prompts used to provide comes
from somewhere else.

Claude Code's [sandbox][claudeSandboxing] is an operating-system
boundary around the commands an agent runs.
It exists on Linux and macOS, and therefore inside WSL2,
and it does not exist on native Windows at all —
there, commands run with the full rights of the user.
That single fact decides the lanes above:
on a Windows machine the headless lane lives in WSL2 or a
[dev container][claudeDevcontainer] with its own firewall,
and the other two lanes bring their own sandbox.
The [environment guidance][claudeSandboxEnvironments] compares the
options.
Skipping permissions entirely is done **only** inside one of those
boundaries, and even there the deny rules and hooks still apply.

Inside a boundary, a run uses the permission mode that lets a classifier
approve ordinary actions and, in headless use, declines anything it
would otherwise have asked about — so the run continues on the safe
path instead of waiting.
The repository's own deny and ask lists still hold, because they are
evaluated first; see [permission modes][claudePermissionModes].
A `PermissionRequest` hook can take the decision instead:
it sees the proposed action and can approve it, refuse it, or forward it
to something that asks a person — and a hook that hears nothing back
refuses.

Every unattended run is started with a ceiling on turns, on spend,
and on wall-clock time, set by the script or workflow that starts it.
A run that hits a ceiling stops and reports.
A run also never touches the default branch:
it pushes a branch and opens a draft pull request,
and the repository's rulesets make sure that is all it can do.

## Asking instead of stalling

The run still meets questions.
What changes is what it does with them:

- **In a headless run**, the question and the assumption the run made
  go into the run's own output, in a section the launcher knows to look
  for, and the run continues along the reversible path.
  The person reads the questions in the morning,
  and the pull request already shows what each assumption produced.
- **In an Actions run**, the run comments on the issue or pull request,
  mentions the repository owner, and ends.
  The owner's reply is the next trigger,
  and the next run sees the whole thread as context.
- **In an interactive session**, the question stays open and is relayed
  to wherever the person is.
- **For a single action that genuinely needs a yes**,
  a headless run can pause at that one tool call and be resumed later
  with the answer; [headless mode][claudeHeadless] calls this deferring.

The brief a run is given therefore always says which of these to do,
and a brief that leaves it unsaid gets the headless default:
record and continue.

## Hearing about it

Notifications are the one place a person's setup and a project's setup
meet, so the split is explicit:
the **project** says nothing about where notifications go;
the **person's** user-level hooks decide.

Today those hooks are local: a line in a log and a toast or a beep,
installed from this repository's `claude/hooks/`.
When a machine is allowed to talk to the outside, the same hook events —
a run finishing, a permission denied, a question raised,
listed under notifications in [hooks][claudeHooks] —
are forwarded to a push service instead,
one topic per repository, with the repository and the kind of event in
the title so several sessions can share a phone without becoming noise.
For the Actions lane, GitHub's own
[notification settings][githubNotifications] already push a mention,
an assignment, or a review request to the phone;
a run that wants to be heard mentions someone.

Replying — approving an action, answering a question, starting a task —
needs a channel back into the session.
[Remote Control][claudeRemoteControl] drives a session on your own
machine from the [mobile app][claudeMobile], prompts included,
and a [hosted session][claudeCloud] is driven from the same app with no
local machine at all; both depend on the account the session is signed
in with allowing them.
The Actions lane is answered by commenting from GitHub's mobile app.
A [channel][claudeChannels] connects a session to a chat service
two-way, including relaying permission prompts;
it is the fallback, not the first choice, because anyone who can reply
to the bot can approve the agent's actions.

## Dictation

Dictation is a property of the surface, not of the agent,
and it needs none of the permissions above.
The Claude Code CLI and its editor extension have their own
([voice dictation][claudeVoice]);
the operating system has one for every other text box;
and for text that should never leave the machine,
an on-device engine such as the editor's speech extension or the
operating system's local voice access.
Which to use is a question of where the audio goes, not of the harness.

## Review by more than one model

A model reviewing its own work shares its author's blind spots.
Every pull request is therefore read by more than one model family
before a person reads it, and the families come from different vendors:

- My reviewer agents, installed from this repository,
  run before the pull request exists.
- [Copilot code review][copilotCodeReview] runs on every pull request
  because a ruleset requests it;
  [automatic review][copilotAutoReview] describes the setting.
  It reads the project's `AGENTS.md` and skills,
  so it reviews against the project's rules, not generic ones.
- A second external reviewer on public repositories reads the same
  files; [CodeRabbit][codeRabbitGuidelines] is one that does.
- For a local second opinion from a different vendor's model
  without leaving the session, the [Copilot CLI][copilotCli]
  runs non-interactively with a model of your choosing
  and reads the project's instructions and skills on the way.

Two things keep this from becoming a loop of bots talking to bots.
Each reviewer **reports**; it never fixes.
And a bot's comment does not trigger another bot:
the Claude action ignores non-human actors unless told otherwise,
and Copilot replies only to people with write access.
A person is always the relay between one model's finding
and another model's fix, which is exactly where a person should be.

## Identity

A run acts as whichever accounts its environment is signed in with —
the agent's own login and the `gh` login.
On a machine with more than one of either,
a run **pins** the identity it should use rather than inheriting
whatever the shell happened to have,
so that an overnight run never opens a pull request as the wrong person
or bills the wrong account.

The clean version of this is a boundary that is also a sign-in boundary:
a WSL2 distribution or a container has its own home directory
and therefore its own logins,
so the identity that runs personal work and the identity that runs work
never share a configuration file.

<!-- GitHub URIs (alphabetical) -->

[claudeGitHubActions]: https://github.com/anthropics/claude-code-action
[copilotAutoReview]: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/configure-automatic-review
[copilotCli]: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
[copilotCloudAgent]: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-on-github
[copilotCodeReview]: https://docs.github.com/en/copilot/concepts/agents/code-review
[githubNotifications]: https://docs.github.com/en/subscriptions-and-notifications/get-started/configuring-notifications

<!-- Public URIs (alphabetical) -->

[claudeAgentView]: https://code.claude.com/docs/en/agent-view
[claudeChannels]: https://code.claude.com/docs/en/channels
[claudeCloud]: https://code.claude.com/docs/en/claude-code-on-the-web
[claudeDevcontainer]: https://code.claude.com/docs/en/devcontainer
[claudeHeadless]: https://code.claude.com/docs/en/headless
[claudeHooks]: https://code.claude.com/docs/en/hooks
[claudeMobile]: https://code.claude.com/docs/en/mobile
[claudePermissionModes]: https://code.claude.com/docs/en/permission-modes
[claudeRemoteControl]: https://code.claude.com/docs/en/remote-control
[claudeSandboxEnvironments]: https://code.claude.com/docs/en/sandbox-environments
[claudeSandboxing]: https://code.claude.com/docs/en/sandboxing
[claudeScheduled]: https://code.claude.com/docs/en/scheduled-tasks
[claudeVoice]: https://code.claude.com/docs/en/voice-dictation
[codeRabbitGuidelines]: https://docs.coderabbit.ai/knowledge-base/code-guidelines

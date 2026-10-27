---
name: delegating-to-agents
description: >-
  Handing work to a subagent and checking what comes back.
  Use when about to spawn, brief, or resume an agent, when reading an
  agent's report, or when writing a skill, agent definition, or prompt that
  another agent will follow.
when_to_use: >-
  Trigger phrases: delegate, subagent, sub-agent, spawn an agent, brief an
  agent, fan out, parallel agents, which model, write a skill, write an agent.
metadata:
  origin: obra/superpowers
  commit: 2ce8aa1
  license: MIT
---

# Delegating to agents

Delegate the reading; keep the judgment. An agent earns its cost when the
work means reading across many files, runs in parallel with other work, or
would flood the main context. A handful of tool calls, or a lookup whose
target is known, is cheaper done directly.

## Choose the model, and name it every time

An agent with no model named inherits the session's, which is usually the
most expensive one.

- `haiku`, at low effort: mechanical retrieval. Find every caller, list the
  migrations, collect the configuration values.
- `sonnet`: read a code path and report how it actually works,
  including the tests and what they assume.
- `opus`: a hard sub-question where being wrong is expensive — the
  concurrency story, the ordering constraint, the failure mode nobody wrote
  down.

Turn count beats token price: the cheapest model often takes two or three
times the turns on multi-step work. Use `sonnet` as the floor for a
reviewer, and for an implementer working from a prose description.

## The brief

A fresh agent knows only its brief. Write it in this order:

1. **Goal**, and one line on where it fits.
2. **Already known or ruled out**, so it does not redo it.
3. **What to read**: paths to files, skills and docs, not their pasted
   content. Hand artifacts over as files: a reviewer gets the diff written
   to a file plus an explicit scope, never a pasted diff.
4. **Scope**: the folders it may edit, disjoint from every other agent's,
   or "read-only". Shared files belong to whoever coordinates.
5. **Verification** to run: named, scoped test runs, never "the whole
   suite" unless that is the point.
6. **The safety block** below, every time.
7. **The report contract** below.

Give an agent code and a question, not your conclusion: handed a
hypothesis, it comes back confirmed. Never pre-judge a finding: if the
brief says "do not flag", "at most minor", or "the plan chose", it is
pre-judging — let the finding be raised, then rule on it.
An agent does not spawn agents of its own; say so when the task invites it.

## The safety block

Copy this into every brief, adjusted only to name the folders:

- Probe only against fakes, sentinels and throwaway folders made for the
  purpose, and delete them afterwards.
- No real external service, account, credential, network write, GUI,
  dialog or installer; git only in a throwaway repository.
- In the working repository, no git writes: no `add`, `commit`, `stash`,
  `checkout`, `switch`, `reset`, `restore`, `clean`, `rebase` or `push`.
- Edit only the folders named. Write each file in one call, because other
  agents may be running tests at the same time.
- Never print a secret; report counts and names instead.
- Leave nothing behind in the repository.

## The report contract

The agent returns one status, then the detail:

- `DONE`: every item done, each with its evidence.
- `DONE_WITH_CONCERNS`: done, with doubts named. Read them before going on;
  a doubt about correctness or scope is settled first.
- `NEEDS_CONTEXT`: something missing. Supply it and resume the agent.
- `BLOCKED`: cannot finish. Change something before retrying — more
  context, a more capable model, a smaller task, or a corrected plan —
  never the same brief again.

Each item is DONE or DISMISSED with its evidence. Then the decisions the
owner may want to reverse, and anything surprising. A long report goes to a
file the brief names; the message carries the status and a summary.

## Checking what comes back

- A report is a claim to probe. Run the tests yourself, check
  `git status`, compare a sample of the work with the diff, and confirm any
  number you will repeat.
- If a finding is wrong, drop it and say why; nothing is dropped silently.
- Never read an agent's transcript or output file with the shell: it is
  large, and it lands in your context. Wait for the notification.

## Fix rounds

A round is one fix plus one scoped re-review of the fix's diff.
Resume the same agent for the first three rounds, since its context is
intact. Rounds four and five go to a fresh agent one model tier up, with
the open findings and the report file. After about five rounds, stop:
park each open finding with a ruling —
`Ruling: <decision> — <why> — <cost if wrong>` — and tell the owner.
Past the cap, rounds do not converge; the failure is structural.

## Writing what an agent will follow

Skills, agent definitions and briefs are instructions to a model:

- A description says **when** to use it — triggers and symptoms — never the
  workflow. An agent that reads a summary of the steps follows the summary
  instead of the skill.
- Match the form to the failure. An agent that knows a rule and breaks it
  under pressure needs a prohibition, with the excuses it makes named.
  An agent that complies but produces the wrong shape needs a recipe: what
  the output is, its parts, in order. A prohibition aimed at a shape problem
  makes it worse.
- A real exception is its own condition on something observable, not a
  "unless it matters" clause, which reopens the rule.
- Keep a skill under about 20 000 characters and 500 lines; move heavy
  reference into a sibling file the skill names and says when to read.

Where a repository's own instructions differ from this skill, they win.

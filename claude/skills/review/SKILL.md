---
name: review
description: >-
  Reviews the current change at a depth scaled to its size and risk.
  Use when asked to review, check, or critique changed code, or before
  opening a pull request.
when_to_use: >-
  Trigger phrases: review this, review my changes, check this before I push,
  is this ready for a PR, what's wrong with this.
argument-hint: "[optional path, 'staged', or 'full']"
allowed-tools: Read Grep Glob Bash PowerShell Agent
metadata:
  origin: obra/superpowers
  commit: 2ce8aa1
  license: MIT
---

# Review

Scale the review to the change. Five parallel reviewers cost roughly fifteen
times a plain conversation: right before a pull request, absurd for a
renamed variable.

Someone else's pull request, given by URL or number, goes through
`reviewing-pull-requests`, which fetches the diff, returns here for steps 2
to 6, and posts the review.

## 1. Establish the diff

Find the default branch
(`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`),
then say which diff you settled on before deciding anything:

- An argument: that path, or `git diff --cached` for `staged`.
  `full` forces every reviewer regardless of size.
- On a branch: `git diff $(git merge-base HEAD origin/<default>)`,
  the branch's commits plus anything uncommitted.
- On the default branch with uncommitted work: `git diff HEAD`.
- Otherwise: `git diff HEAD~1`.

If nothing changed, say so and stop. Do not invent a scope.

Write `git diff --stat` and `git diff -U10` for that range into one uniquely
named file outside the repository. That file is what every reviewer reads,
so the diff never has to be pasted into a brief.

## 2. Choose the depth

Read the stat and the file list first, then pick:

- **Two files or fewer, under ~50 lines, no new public surface**:
  review it yourself, inline. No agents.
- **Anything larger**: the lenses the diff actually implicates.
- **Before a pull request, `full`, or anything touching authentication,
  cryptography, input parsing, secrets, workflow permissions, or a public
  API**: every lens. Do not economize there.

## 3. Pick the lenses

- **`security-reviewer`**: handles input, credentials, tokens, paths, shell
  or SQL; changes a workflow `permissions:` block; adds a dependency.
- **`performance-reviewer`**: adds or changes a loop, a query, an I/O call,
  an async path, or anything that runs per item.
- **`quality-reviewer`**: adds or restructures logic, types, or control
  flow. Skip it for a pure rename or a formatting pass.
- **`test-reviewer`**: changes behavior, or touches test files.
  Skip it when the change genuinely cannot have a test.
- **`docs-reviewer`**: renames anything, adds or removes a file, changes a
  parameter or a step, or edits a document.
- **`silent-failure-hunter`** (optional): adds or changes error handling,
  a retry, a fallback, a default on failure, or a caught exception.
- **`type-design-analyzer`** (optional): adds or reshapes a type, record,
  interface or schema.

An optional lens runs only when its agent is installed; otherwise do that
read yourself or report it as skipped. A docs-only change usually needs
`docs-reviewer` alone; a formatting pass usually needs nothing.

## 4. Fan out

Dispatch the chosen reviewers in **one message**, so they run concurrently.
Give each an explicit scope: the diff file's path, the file list, and the
one question its lens answers. Vague briefs are the main reason parallel
reviewers duplicate each other.

Ask every reviewer for the same two things:

- Findings as `path:line`, graded by their effect on a reasonable person
  reading or using the code. Where the spec or the docs are silent, what
  that person would expect is still a requirement; silence is not permission.
- A **Declined to judge** list: every behavior it considered and set aside
  as out of scope, one line each with the reason. An empty list means it
  set nothing aside.

Never pre-judge in a brief: no "do not flag X", no "at most minor".
If a finding would be a false positive, let it be raised and rule on it here.

## 5. Say what ran

Before the findings, one line: which reviewers ran, which were skipped, and
why. A review whose depth is invisible can be neither trusted nor corrected.

## 6. Synthesize

One list, most severe first. Merge the same defect seen through two lenses,
keeping the sharper explanation and noting both angles.
Rank by consequence, not by which reviewer raised it:

1. Exploitable, or wrong results.
2. Will break under real load or real data.
3. Untested behavior that can regress silently.
4. Documentation that is now wrong: a reader will trust it and be misled.
5. Design that will cost the next reader time.
6. Convention drift, or documentation that is merely missing.

For each finding: `path:line`, a sentence on the defect, a sentence on the
fix. If a reviewer returned something you can see is wrong, drop it and say
why; five agents reporting confidently is not five agents being right.

Then the merged **Declined to judge** list, for the person to rule on:
nothing set aside is dropped silently. Then a line or two on what was
**not** found, so a clean result shows the clean parts were looked at.

## 7. Report and stop

Do not fix anything unless asked. The point of a review is to let a person
decide what is worth changing.

Where a repository's own instructions differ from this skill, they win.

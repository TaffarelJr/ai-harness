---
name: commit
description: >-
  Turns the current changes into Conventional Commits, one concern per commit.
  Use when asked to commit, to stage and commit work in progress, or to write
  a commit message.
when_to_use: >-
  Trigger phrases: commit this, commit my changes, write a commit message,
  stage and commit, split this into commits.
argument-hint: "[optional scope hint]"
allowed-tools: Read Grep Glob Bash PowerShell
---

# Commit

## 1. Never commit to the default branch

Find the default branch instead of assuming its name:
`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`,
or `git symbolic-ref --short refs/remotes/origin/HEAD` without a network.
On it, create a descriptive branch and switch to it before anything else.

If the editor shows unsaved changes in a file about to be committed,
say so and wait: the commit would miss them, and unsaved content is
unrecoverable.

## 2. Read what actually changed

`git status --porcelain`, then `git diff` and `git diff --cached`.
Read the diff, not the file names: the message describes intent,
and a file name does not carry it.
A change you do not recognize is someone else's work;
leave it alone and say so.

## 3. Group by concern

One commit, one concern. Split wherever the answer to
"what kind of change is this?" differs:

- a behavior change,
- a fix for a specific defect,
- a rename or restructure with no behavior change,
- formatting only,
- docs only,
- tests only.

Stage each group by pathspec, `git add -- <paths>`, never `git add -A`.
When one file holds two concerns, stage part of it from a trimmed patch
(`git diff -- <file>` to a file outside the repository, cut it down,
`git apply --cached`) rather than `git add -p`, which waits for input.

While a pull request is open, a fix to something it introduced is not a
new commit: fold it into the commit that introduced it (`stacked-pull-requests`).
Nothing churns either: a pull request never adds a file in one commit
only to move or delete it in a later one.

## 4. Write the message

When the repository documents its own format — a commit convention in
`docs/`, `CONTRIBUTING.md`, a commitlint configuration — that wins,
custom types included. Otherwise use the standard Conventional Commit
types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`build`, `ci`, `chore`, `revert`.

- `type(scope)!: description`, with the scope only when it narrows
  something, and `!` (or a `BREAKING CHANGE:` footer) when callers have
  to change.
- Imperative present tense: "change", not "changed" or "changes".
- The subject says **what** changed, fits on one line,
  and makes sense without the body.
- No issue, story or work-item reference (`#N`, `Closes #N`, a work-item
  id): the pull request description carries it.
- Add a body only when a *why* needs saying: the constraint worked around,
  the approach that failed, the defect the diff does not reveal.
  A few lines wrapped at 72. A body that restates the subject is noise;
  one that runs past a short paragraph is describing the diff.
- End the message with the attribution trailer the session specifies,
  after a blank line, and add no trailer it does not.

## 5. Verify, then commit

- Every commit stands on its own: the repository builds and the tests the
  change can affect pass at that commit, not only at the last one.
  The repository says how much to run.
- Show the message and the exact file list for each commit.
- Commit from a message file outside the repository (`git commit -F <file>`),
  so the shell cannot mangle quotes or backticks.
- Confirm with `git log --oneline -1` and `git status --short` that it
  landed as intended and nothing was swept in.

Do not push. Pushing is a separate decision, and a person makes it.

Where a repository's own instructions differ from this skill, they win.

---
name: pull-request
description: >-
  Opens a draft pull request for the current branch, described from the
  commits it actually contains. Use when asked to open, raise, or create a
  pull request, or when a branch is ready for review.
when_to_use: >-
  Trigger phrases: open a PR, raise a pull request, create a draft PR,
  this is ready for review, push this up for review.
argument-hint: "[optional title]"
allowed-tools: Read Grep Glob Bash PowerShell
---

# Pull request

## 1. Check the branch

- Find the default branch:
  `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
  On it, stop and say so: there is nothing to open a pull request from.
- Check the active `gh` account is the one the folder's `CLAUDE.md` names
  (`gh auth status --active`) before any call below.
- Nothing uncommitted belongs in it. Show `git status --porcelain` and ask
  before including or ignoring anything unexpected.
- The base is the default branch, or the branch below in a stack.
  `git fetch origin`, then `git merge-base --is-ancestor origin/<base> HEAD`;
  if the base has moved on, rebase onto it so the diff shows only this work.
  The branch is yours and open, so rewriting it is fine (`stacked-pull-requests`).
- More than one pull request in play — this branch builds on another
  unmerged one, or the work is splitting — means a stack: follow
  `stacked-pull-requests`, and use this skill for each pull request in it.

## 2. Read what the branch contains

`git log --oneline origin/<base>..HEAD` for the commits and
`git diff origin/<base>...HEAD --stat` for the shape.

The description comes from the **commits**, not from memory of the
conversation. If the commits do not explain the change, fix the commits
first; the description should not have to compensate.

## 3. Write the description

Follow `.github/pull_request_template.md` when the repository has one,
filling in its actual sections. Otherwise:

- **Why**, in a sentence or two: the problem, not the diff.
- **What changed**, as bullets grouped by concern, mirroring the commits.
- **How it was verified**: the commands run and what they reported.
  "Tests pass" is not verification; the output is.
- **What is left out**, and why. Reviewers need this most and get it least.

Keep it readable in a minute: a line per bullet, a sentence or two per
section. A description longer than its change is a sign to cut.

Reference the tracker the folder's `CLAUDE.md` names:

- A GitHub issue: `Closes #N` only when merging completes the issue,
  otherwise `Refs #N`.
- Work items in Azure DevOps: `AB#<id>`, which links the pull request to
  the item.

End with the attribution line the session specifies. Write the body to a
file outside the repository; Markdown backticks stay unescaped.

## 4. Push and open it as a draft

```powershell
git push -u origin <branch>
gh pr create --draft --base <base> --title '<title>' --body-file <file>
```

The title is a Conventional Commit subject: the commit's own when there is
one, a summary of the concern when there are several.
Report the URL.

To change the description later, edit the file and send it whole:
`gh api -X PATCH repos/{owner}/{repo}/pulls/<number> -F body=@<file>`.

Never merge it, mark it ready, enable auto-merge, approve it,
or request a reviewer — a person or a review bot — unless asked.
A person marks it ready and merges it.

## 5. Say what will be checked

`gh pr checks <number> --required` lists the required checks by the names
the repository declares; do not name them from memory. If one is already
failing, say which, instead of leaving it to be discovered.

Where a repository's own instructions differ from this skill, they win.

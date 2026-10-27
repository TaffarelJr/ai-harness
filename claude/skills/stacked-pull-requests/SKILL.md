---
name: stacked-pull-requests
description: >-
  The owner's rules for pull requests that are still open: stacks of draft
  pull requests, folding fixes into the commits that introduced them, and
  restacking and pushing rewritten branches safely. Use when more than one
  pull request is in play, when a fix belongs in an earlier commit of an open
  pull request, after a lower branch of a stack changed, or before any
  force-push.
when_to_use: >-
  Trigger phrases: stacked PR, stack these, gh stack, link the PRs, fold the
  fix, restack, rewrite history, force push, rebase the stack.
---

# Stacked pull requests

## The rules

- The default branch is never rewritten, force-pushed, or pushed to
  directly. Work reaches it only through pull requests,
  and only a person merges them.
- Every pull request is a **draft**; a person marks it ready.
  Never merge, enable auto-merge, `gh pr ready`, `gh stack merge`,
  or `gh stack link --open`.
- Any other branch may be rewritten while its pull request is open: that is
  how it gets clean. A branch someone else pushes to, or builds on outside
  the stack, is shared; ask before rewriting it.
- While a pull request is open, a fix is **folded** into the commit that
  introduced the thing (`folding.md`), never appended as a fix commit.
  Each commit carries one concern, the repository builds and its tests pass
  at every commit, and nothing churns.
- Merged history is never rewritten. A fix to merged code is a new commit
  in a new pull request.
- More than one pull request in play means a **stack**, linked as soon as
  the pull requests exist.

## Building a stack

1. Each branch builds on the one below it. Its pull request targets that
   branch; the bottom one targets the default branch.
2. Open each as a draft with the right `--base` (`pull-request`).
3. Link them bottom to top, by pull request number:
   `gh stack link <bottom> <next> <top>`.
   To grow a stack, pass its stack number first:
   `gh stack link <stack-number> <new>`.
   Use numbers, not branch names: a branch without a pull request gets one
   created for it.
4. The link survives a restack; there is no need to link again.

If `gh stack` is not available, say so: the base branches still chain the
pull requests, and the owner can link them.

## When a lower branch changes

GitHub treats the two cases differently:

- **It moved forward** (new commits pushed on top): GitHub rebases the
  branches above it itself, with the same content and new commit ids.
  The local copies are now stale; see the last section.
- **It was rewritten** (a fold, a rebase, an amend): GitHub does **not**
  rebase the branches above. Their pull requests show the old commits as
  extra changes until you restack.

## Restack

Nothing else may be editing the tree while this runs.

1. `git fetch origin`, then record each branch's fetched tip:
   `git rev-parse origin/<branch>`. The leases below compare against these.
   A local branch that differs from its fetched tip is dealt with first
   (last section).
2. Rewrite. After a fold on the top of the stack (`folding.md`), the whole
   line is already rewritten: point each lower branch at its counterpart
   commit in the new history, matched by subject, with `git branch -f`.
   After any other rewrite of a lower branch, replay each upper branch onto
   it, bottom up, recording each old tip before moving it:
   `git rebase --onto <new lower> <old lower> <upper>`.
3. Verify each branch before pushing anything:
   `git range-diff <old base>..<old tip> <new base>..<new tip>` shows only
   the intended changes, and the top's tree is the tree expected.
4. Push every rewritten branch in one atomic push, each with an explicit
   lease on the tip fetched in step 1:

   ```powershell
   git push --atomic origin "--force-with-lease=<b1>:<fetched1>" "--force-with-lease=<b2>:<fetched2>" <b1> <b2>
   ```

   A bare `--force-with-lease` is only as good as the last fetch,
   and an editor may have fetched in the background since.
5. Check each pull request shows only its own commits:
   `git log --oneline origin/<base>..origin/<branch>`.

A rejected lease means someone else moved the branch: fetch, find out what
changed, and start again. Never retry with a plain `--force`.

## When GitHub re-synced a branch

A branch GitHub rebased after a lower one moved forward has new commit ids
(committer `GitHub`) and the same content. Locally it looks diverged.

1. `git fetch origin`.
2. `git diff <branch> origin/<branch>`. Empty means only the ids changed:
   move the local branch to the fetched one
   (`git branch -f <branch> origin/<branch>`, or from the branch itself,
   `git reset --keep origin/<branch>`).
3. Local commits GitHub has not seen are replayed onto its version:
   `git rebase --onto origin/<branch> <old fetched tip> <branch>`.

Never push a stale local branch over GitHub's version.

Where a repository's own instructions differ from this skill, they win.

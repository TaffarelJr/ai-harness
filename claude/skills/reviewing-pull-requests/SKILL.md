---
name: reviewing-pull-requests
description: >-
  Reviews someone else's pull request and posts the review on it: inline
  comments, an approval or a held approval, and re-reviews after the author
  pushes. Use when given a pull request URL or number to review that another
  person authored, when an author has pushed changes or replied to a review
  already posted, or when an approval was dismissed by a new commit.
when_to_use: >-
  Trigger phrases: review this PR, review PR, new PR to review, re-review,
  the author made changes, the author replied, approve it, needs a review,
  take a look at this pull request.
argument-hint: "<pull request URL or number>"
allowed-tools: Read Grep Glob Bash PowerShell Agent
---

# Reviewing pull requests

The review is posted under the owner's name, to the pull request's author.
Every word in it is the owner speaking.

## 1. Orient

- Check the active `gh` account is the one the folder's `CLAUDE.md` names
  before every call; the active account can change between two calls.
- Name the repository in every call: `--repo <owner>/<repo>` on `gh pr`
  commands, and a literal `repos/<owner>/<repo>/...` path for `gh api`.
  `gh` fills `{owner}/{repo}` from the current directory, and pull request
  numbers repeat across repositories, so a placeholder can post the review
  on another repository's pull request with the same number.
- Read the pull request: title, description, commits, files, checks,
  every review, and every thread with its resolved state.
- Fetch the head to a named ref (`refs/review/pr<n>`) in a clone of that
  repository, never into the working branch; `FETCH_HEAD` is overwritten by
  the next fetch.
- Diff against the merge base, so the review shows only this pull
  request's work.

## 2. Review it

Use `review` steps 2 to 6 for the depth, the lenses and the synthesis,
with the fetched ref as the diff. Then verify what neither the diff nor
CI can show, read-only:

- Live values the change depends on: identifiers it seeds, settings it
  expects, the versions a server reports.
- A branch the tests never reach, such as code that runs only in one
  environment. Exercise it against a throwaway copy, never a shared one.
- Anything the description claims. A claim is a lead, not a fact.

A reviewer agent's finding is a lead too: re-run what it cites before
repeating it.

## 3. Decide

Each finding is one of three things:

- **Outstanding** — wrong, or a question that must be answered before
  merge. It holds the approval.
- **A recommendation** the author can take or leave. It does not hold the
  approval; word it as optional.
- **Not worth saying.** It goes in the report to the owner, never on the
  pull request.

Never comment on the format of a title, a commit message, or a tracker
reference. Those are the author's.

## 4. Post it

One review, carrying one inline comment per finding.

```powershell
gh api --method POST repos/<owner>/<repo>/pulls/<n>/reviews --input <file>
```

The file holds `commit_id` (the head), `event`, an optional `body`, and
`comments`: `{ path, line, side: "RIGHT", body }` each. A line must be in
the diff or the call fails with 422; attach an off-diff finding to the
nearest changed line and say so.

- **No outstanding items**: `"event": "APPROVE"`, even when the pull
  request already has the approvals it needs.
- **An outstanding item**: `"event": "COMMENT"`, and no approval until it
  is dealt with.

A submitted review cannot be deleted. Its body can be edited with
`PUT .../reviews/<id>`, which needs a body in the request: an edit sent
without one fails with 422 "Could not edit a review with a missing body".
When an edit will not do, submit a fresh review.

## 5. What is written

Shape, for each piece:

- **An inline comment**: the claim, the consequence, the fix.
  Two short sentences, three at most.
- **A review body**: empty by default. One sentence only when it tells the
  author something they cannot see for themselves: a check that went
  beyond CI, or a reminder of items they deferred, when approving anyway.
  Never praise, never a summary of the comments, never a list of what was
  verified.
- **A reply in a thread**: one or two sentences, or an emoji, or nothing.

These rules are broken under pressure, with the same excuses each time.
They are not exceptions:

- "I checked a lot, so the body can say so." The depth of a review and the
  length of its report are independent. Report the verdict.
- "This finding matters, so it needs more words." Importance is in the
  claim, not the length.
- "Each point needs its reason." A reason on every line is the wall of text.
- "Let me explain how I found it." The author needs the defect and the
  fix, not the investigation.

Count the sentences before posting. More than three in any one piece is
already too many.

## 6. Threads

- **Another reviewer's or a bot's thread**: add to it only when bringing
  something it lacks — the evidence that settles it, a gap in the fix, why
  it does not apply. "I agree" adds nothing.
- **A person's question**: an answer goes in their thread, not in a new
  comment.
- **Your own thread**: resolve it once the author has decided — fixed,
  deferred, or declined — after verifying any fix they claimed.
- **Any thread the author resolved**: it is decided. Never reopen it, even
  if the finding stands; a reply that adds real value may stay.
  An item the author resolved or deferred no longer holds the approval.
- Never resolve anyone else's thread.

## 7. Re-review

Where the repository dismisses stale approvals, a new commit dismisses an
earlier one. Check your own review's state
(`gh pr view <n> --repo <owner>/<repo> --json latestReviews`), not the
overall decision, which other reviewers' approvals can hold up.

1. Diff the head you reviewed against the new head; that is all that
   changed.
2. Verify each claimed fix in the code, not in the reply.
3. Resolve each of your threads it settles. Comment again where a fix
   falls short.
4. Approve again, usually with no body. Resolving a thread is not an
   approval.

## 8. When asked "are you sure?"

That is a request to confirm, not a sign of a mistake. Check, then answer
with the deciding evidence. Change, move, or delete what was posted only
when the check shows it was wrong.

## 9. Report and clean up

To the owner, not on the pull request: what was posted, with links; what
was verified; and what was set aside and why. Then remove the fetched ref
and every scratch file, folder, and throwaway database made for the review.

Never merge, mark ready, or request a reviewer.

Where a repository's own instructions differ from this skill, they win.

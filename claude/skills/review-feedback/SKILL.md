---
name: review-feedback
description: >-
  Handles review comments on a pull request, from a person or a bot.
  Use when a pull request has review comments or open threads, when review
  feedback arrives in chat, or after pushing a fix for one.
when_to_use: >-
  Trigger phrases: review comments, review threads, resolve the threads,
  address the feedback, reply to the review, bot comments.
metadata:
  origin: obra/superpowers
  commit: 2ce8aa1
  license: MIT
---

# Review feedback

A comment is a claim to probe, not an instruction.
Verify before implementing; technical correctness over social comfort.

## The loop

1. **Read everything first**: the threads (below), plus the review bodies and
   conversation comments (`gh pr view <number> --comments`).
2. **Understand every item.** If any item is unclear, stop and ask about all
   the unclear ones before implementing any: items are often related, and a
   partial understanding produces a wrong fix. In a thread, ask in a reply;
   in chat, ask the person.
3. **Verify each against the code.** Reproduce it. Check whether the change
   would break something, why the current code is the way it is, and whether
   it holds on every platform and version the code supports. When it
   contradicts a decision the owner already made, raise it with the owner
   instead of picking a side. When it cannot be verified, say what would
   verify it.
4. **YAGNI check.** A request to "implement it properly" first gets a search
   for real callers. Nothing uses it: propose removing it instead.
5. **Fix in order**: blocking (breaks, security), then simple, then complex.
   Test each fix on its own, running the tests that change can affect.
6. **Fold, do not append.** Each fix goes into the commit that introduced the
   thing, then the stack is restacked and pushed (`stacked-pull-requests`).
7. **Reply to every thread**, applicable or not, in a sentence or two:
   what changed and where, or the technical reason nothing did. Where the
   folder's `CLAUDE.md` says to reply only when a reply adds something,
   skip the rest; an emoji is fine when the commit already says it.
8. **Resolve** the thread once the point is dealt with or answered.
   Where the folder's `CLAUDE.md` says to resolve only a bot's threads,
   leave a person's for them: it is their signal to look again.
   A thread with an open question stays open until it is answered.

Never post a comment announcing that the feedback was addressed, and never
put one in a review body: the thread replies and the commits already say it.

Handle a stack bottom up: a fold in a lower pull request rewrites every one
above it.

Never request another review from a bot yourself; the owner decides when one
is worth it.

## How to reply

State the fix or the reasoning, and stop: one or two sentences.
More than that is narrating the investigation, which the reader does not
need, however much of it there was.

- It applied: "Fixed: the guard now rejects an empty name (`src/parse.py:41`)."
- It did not: "The only caller (`build.py:88`) already trims, so this cannot
  be empty; leaving it."
- It is unclear: "Does this mean the error path or the warning path?
  They differ."
- Your own pushback was wrong: "Checked: it does return null there.
  Fixed in `src/items.py:20`." No apology, no defense.

No performative agreement and no thanks: not "great point", not "you're
absolutely right". The code shows the feedback was heard.
Write a reply like a commit message: true, specific, free of history,
and never containing a secret.

## Read the threads

```powershell
$query = @'
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id isResolved isOutdated path line
          comments(first: 30) { nodes { author { login } body } }
        }
      }
    }
  }
}
'@
gh api graphql -f "query=$query" -F owner='{owner}' -F name='{repo}' -F number=12
```

`gh` fills `{owner}` and `{repo}` from the current repository.
`isOutdated` means a push moved the lines a comment was about,
not that the point was dealt with.

## Reply and resolve

```powershell
$reply = @'
mutation($id: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $id, body: $body}) { comment { id } }
}
'@
$resolve = 'mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
gh api graphql -f "query=$reply" -f "id=$threadId" -f "body=$text"
gh api graphql -f "query=$resolve" -f "id=$threadId"
```

Build each field as one quoted `"name=$value"`: in PowerShell,
`-f id=$item.thread` expands only `$item`.
Each reply appears as a review of its own under the replier's name.

Where a repository's own instructions differ from this skill, they win.

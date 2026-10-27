---
name: deep-plan
description: >-
  Investigates the codebase with subagents, then produces a detailed
  implementation plan: the files that change, in what order, what each change
  is for, and what could break. Use when a change is large or risky enough to
  plan before any code is written.
when_to_use: >-
  Trigger phrases: plan this, deep plan, make an implementation plan, how
  would you build this, what would this touch.
argument-hint: "[what to plan]"
disable-model-invocation: true
model: fable
effort: xhigh
metadata:
  origin: https://github.com/obra/superpowers
  commit: 2ce8aa1
  license: MIT
  note: >-
    Stand-in for a plan-mode model switch that has no fable alias: opusplan
    plans on opus and builds on sonnet; the model and effort fields above do
    the same for one invocation, which is why this skill is invoked by hand.
    If an alias that plans on fable ever ships, prefer it and keep the method.
---

You are orchestrating. Delegate the reading; keep the judgment.

## Know what you know

Before investigating, write down in a few lines what the request settles and
what you are assuming: the goal, who it is for, what done looks like, the
constraints. Mark each line *known* (stated, or seen in the code) or
*assumed*. Let the investigation settle every assumption it can. What remains
and would change what gets built comes to me, as few questions as possible.
When nothing important is missing, say so and carry on.

## Investigate

Spawn subagents for investigation and name a model on each one. They
inherit your model by default, which is not what you want for file
reading:

- `haiku` at `low` effort — mechanical retrieval. Find every caller,
  list the migrations, collect the config values.
- `sonnet` — read a code path and report how it actually works,
  including the tests and what they assume.
- `opus` — a hard sub-question where being wrong is expensive: the
  concurrency story, the ordering constraint, the failure mode nobody
  wrote down.

Run the independent ones in parallel. Then do the part that doesn't
delegate: reconcile what came back and name the constraints and where they
were found.

## Choose an approach

When the design is open, lay out the real alternatives before committing to
one, and drop the weak ones. Where the shape of the change is open, weigh
three: a *minimal* one (the smallest change, reusing what exists), a *clean*
one (the structure you would choose starting fresh), and a *pragmatic* one
(between the two). Ground each in what the code does today and say what it
trades off. Recommend one and say why.

When one way is clearly right, say so and why the others don't fit, then
carry on. Otherwise ask me which, and write no plan until I answer.

## Write the plan

The files that change, in what order, what each change is for, and what could
break. Cut the work into tasks, each the smallest unit that carries its own
check and that a reviewer could reject while approving its neighbor. Fold
setup and documentation into the task that needs them. Format each task like
this:

```markdown
### Task N: <deliverable>

**Files:** create `path/new`; modify `path/existing` (the function); test
`path/test`.

**Consumes:** what this task uses from earlier ones, with exact names and
signatures.
**Produces:** what later tasks rely on, with exact names, parameters, and
return types. An implementer sees only their own task, so this is how they
learn their neighbors' names.

1. Write the failing check: its name and its assertions, with the exact
   values the request fixes.
   Run `<command>`. Expect: fails with `<message>`.
2. Implement `<signature>` in `<file>`. Add one line on the approach only
   where the signature and the check leave a real choice.
3. Run `<command>`. Expect: passes.
```

A step is done when the implementer could write exactly one reasonable thing
from it: a signature and the values the request pins, not the body. A body
belongs only where the signature and the checks do not determine it. Where
code has no test, the check is a command and the output that means it worked.

## Check the plan

1. **Builder check.** Spawn a fresh `sonnet` subagent that has not seen this
   conversation. Give it the plan's path and this brief: "You are an engineer
   handed this plan and the repository, and you cannot ask its author
   anything. List only the questions you would still need answered before you
   could build it well: places you would have to guess where a wrong guess
   matters, each with why the answer changes the work, ranked. Skip what the
   plan leaves to the builder and anything you could reasonably decide
   yourself. If nothing important is left, say so." Sort what comes back:
   *already answered* goes into the plan; *minor* you settle and mark in the
   plan as your call; *mine* come to me in one message, most important first.
2. **Coverage.** Every requirement in the request maps to a task. List any
   that do not.
3. **Consistency.** Names, signatures, and types in later tasks match what
   earlier tasks define.
4. **Step scan.** A line that decides nothing ("handle edge cases", "add
   validation", "write tests for the above") is a gap. A body the signature
   and checks already determine is a transcript.
5. **Proportion.** A plan longer than the code it describes has written the
   code instead. Replace bodies with signatures and assertions, then confirm
   each step is still unambiguous.

Fix what you find inline.

Flag anything no subagent could verify by reading the code. I'd rather have an
open question than a guess.

Where a repository's own instructions differ, they win.

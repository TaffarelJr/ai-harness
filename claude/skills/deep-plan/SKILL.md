---
description: Investigate the codebase, then produce a detailed implementation plan
disable-model-invocation: true
model: fable
effort: xhigh
---

You are orchestrating. Delegate the reading; keep the judgment.

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
delegate: reconcile what came back, name the constraints and where they
were found, and write the plan — the files that change, in what order,
what each change is for, and what could break.

Flag anything no subagent could verify by reading the code. I'd rather
have an open question than a guess.

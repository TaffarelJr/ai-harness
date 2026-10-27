---
name: test-driven-development
description: >-
  Drives a change test-first, one behavior per cycle, when invoked by name.
  Use when starting a feature, or when fixing a bug that should have had a
  test.
when_to_use: >-
  Trigger phrases: /test-driven-development, test first, red green refactor,
  TDD this.
argument-hint: "[what to build or fix]"
disable-model-invocation: true
metadata:
  origin: obra/superpowers
  commit: 2ce8aa1
  license: MIT
---

# Test-driven development

Work in one-behavior cycles. No production code without a failing test
demanding it.

## Before the first cycle

State the behavior in one sentence and list the cases to cover:
the happy path, the boundaries (empty, one, many; zero, negative, maximum),
and the errors. Get agreement on the list before writing anything; it is
the cheapest moment to catch a wrong assumption.

Find the existing tests for the nearest comparable code and match their
structure, naming and assertion style. Existing patterns outrank anything
here.

## Design for seams

Most paths should be unit-testable with fakes. Put the clock, the network,
the file system, processes and external services behind a seam — a
parameter, an interface, an injected function — and keep the logic on this
side of it. A test that needs a mock for everything is a design that needs
a seam.

Integration tests are few. Each proves real connectivity: the real thing
answers, the credentials work, the wire format is what the code expects.
Keep them separate — their own folder, a tag, or a switch — so the unit
suite stays fast and runs anywhere. The repository says where they run.

## The cycle

**Red.** Before writing the test, name the production change that would
make it fail. If none comes to mind, the test is aimed at nothing observable;
redesign it. Write exactly one test for the next case. Run it, and check it
fails *for the reason expected*: a test that passes at once, or fails on a
typo, proves nothing.

**Green.** Write the least code that passes, not the design in mind.
Run the test, then the tests the change can affect; the repository says
how much to run. Any failure seen goes in the report by name, including one
you did not cause.

**Refactor.** Improve the shape with the tests as the net, and run them
again. Not optional: this is where the design comes from.

Then stop and report the cycle — the case, the failure you saw, the change,
and the tests run with their result — before starting the next.
One behavior per cycle; never two failing tests at once.

## Test quality

- **Arrange / Act / Assert**, one case per test, one act per test.
- **Behavior, not implementation.** A test that restates the code breaks
  on every refactor and catches nothing.
- **Hand-derived expected values.** Literals and hand-checked fixtures;
  never an expectation computed by the code under test or its helpers,
  which passes whatever the code does. Table-driven cases with literal
  expectations are fine; branching in a test is not.
- **No change detectors.** A test only an intentional decision can fail —
  a constant's value, exact wording, private structure — fires on redesign
  and sleeps through bugs. Test the behavior that depends on the decision.
- **A mock earns no assertions.** Asserting a mock exists or was set up
  proves nothing about the component. Assert on the component's behavior;
  where the call to a dependency *is* the contract (the request sent, the
  file written), assert the recorded call with exact values.
- **Fakes mirror reality.** Give a fake the complete structure the real
  thing returns, and learn a real method's side effects before replacing
  it. Cleanup only tests need lives in test utilities, not production code.
- **Names describe the case**: what goes in, under what condition, what
  comes out. When it goes red, the name says what broke.
- **Cover the error paths.** Untested failure handling is usually broken.

## When to stop

Stop when every case on the list is green and no branch is unreached.
Then mutate the code in your head — a wrong constant, the wrong branch, a
missing side effect, an empty return, a missing check for empty or
malformed input — and confirm a test fails for each. One that nothing
catches is an unprotected behavior.

Be honest about coverage: meet the gate the repository declares, say plainly
what is left uncovered and why, and never write a test only to move the
number.

## Bugs

A bug means a test was missing. Reproduce it as a failing test first, in
the smallest form possible, then fix it. That test is what stops it coming
back; the fix alone does not.

Where a repository's own instructions differ from this skill, they win.

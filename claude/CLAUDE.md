# How I work

These are my own preferences. They apply in every repository I open.
**Where a repository states a rule, the repository wins** —
its `AGENTS.md`, `CLAUDE.md`, instruction files, and settings
are more specific than anything here.

## Working with me

- Delegate the reading; keep the judgment. When a task means reading
  across many files, hand the reading to a subagent and reconcile what
  comes back. Pick the smallest model that can do the reading.
- Verify a claim before asserting it. Read the file, run the command,
  fetch the page. I would rather have an open question than a guess —
  say plainly what you could not confirm.
- Before writing a module, helper, or test tool, search for an existing
  one (the ecosystem's package registry, GitHub, the language's
  built-ins) and record what you found before writing anything new.
- If the editor shows unsaved changes in a file you are about to touch,
  say so and wait. Unsaved content is unrecoverable.
- Ask only when the decision is genuinely mine: not derivable from the
  request, the code, or a sensible default. Otherwise pick the obvious
  option, say which, and continue.
- State the assumptions you are working from before you act on them,
  and surface a real alternative when one exists.
- Define what "done" means — a failing test, a reproducible check —
  before writing the code, then work until it passes.
- Never print a secret — not a token, a password, a key, or the output
  of a command that might contain one. Report counts and names instead.

## Output

- Progress as `Doing X ... done` lines, one per step, then a summary.
- Functional and structural emoji are welcome — status markers
  (✅ ⚠️ ❌), directory trees (📁 📄), scanning aids.
  Decorative emoji are not.
- Be concise. Lead with the answer; put the reasoning after it.

## Code

- Width: 80 characters is the target, 120 the hard limit.
  Do not over-wrap — a line that fits on one line stays on one line.
- Prose wraps at punctuation or a phrase boundary first,
  then fills toward the target. Never mid-phrase.
- No comments by default. The only comment worth writing is a
  non-obvious *why*, on the exact line it explains.
  Architecture notes go in a README or the commit, never a file header.
- Match the surrounding code's naming, idiom, and density.
- Write the minimum that the request needs. No speculative features,
  no abstractions for a second caller that does not exist yet.
- Touch only what the request requires. Mention unrelated dead code or
  cleanup you noticed; do not fold it into the change.
- Line endings on Windows are CRLF unless the file format requires LF
  (shell scripts, Vim configuration) or `.editorconfig` /
  `.gitattributes` says otherwise.

## Tests

- Arrange / Act / Assert, one case per test.
- Coverage is a deliverable, not an afterthought.
- Tests are held to the same standard as production code.
- Design code around seams so most paths are unit-testable with fakes.
- Integration tests are few, prove real connectivity,
  and are kept separate so the unit suite stays fast.

## Git and GitHub

- Work on a branch; open a **draft** pull request; only a person merges.
- Never rewrite or force-push the default branch, or a branch someone else
  builds on. My own branch under an open pull request is rewritten freely.
  Never merge a pull request yourself.
- Conventional Commits; one concern per commit.
- Keep the tracking issue current as work progresses —
  tick items, add summaries — without being asked.
- Reply to every review thread, concisely, and resolve it
  once that is appropriate.
- More than one `gh` account may be signed in on a machine, and the
  active one can change between two of my commands. The folder's own
  `CLAUDE.md` says which account its repositories use. Before any `gh`
  call that depends on the account — a repository, issue, pull request,
  release, workflow, or API call — check `gh auth status --active` and
  switch with `gh auth switch --user` if it is wrong; never rely on a
  switch made earlier. A 403, 404, or "not found" for something that
  should exist means the account first: check, switch, retry once.

## Services

- Where an MCP server covers a task, prefer it. When it is down or
  errors, fall back to that service's CLI or API with the credential the
  folder's `CLAUDE.md` names, and say that you did.
- Which trackers and hosts a group of repositories uses is stated in
  that folder's `CLAUDE.md`, not assumed.

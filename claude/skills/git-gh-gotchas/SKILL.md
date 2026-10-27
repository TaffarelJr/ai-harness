---
name: git-gh-gotchas
description: >-
  Verified behavior of git and the GitHub CLI that breaks non-interactive use:
  editors and prompts that block, operands read as options, exit codes that
  are answers rather than failures, output formats and separators that lie,
  flags that only take one spelling. Use when running git or gh without a
  terminal, parsing their output, scripting or wrapping either tool, or when a
  git or gh command hung, opened an editor, or returned something unexpected.
when_to_use: >-
  Trigger phrases: editor opened, git hung, gh hung, parse git output, gh
  --json, porcelain, exit code 1, rebase --continue, gh api, gh gist, gh pr
  create, gh pr checks, boolean flag, end of options.
---

# git and gh gotchas

Two reference files, each verified against the tool and its source. Read the
one for the tool at hand before relying on a flag, an exit code or an output
format; read both when a script drives the two together.

- [git.md](git.md): keeping git unattended (editor, prompts, credential
  helpers), operands that start with a dash, reading state from porcelain
  output, exit codes that mean "no", stderr on success.
- [gh.md](gh.md): argument shapes (`--flag=value`, `--`, slice flags, search
  keywords), commands that open an editor or prompt without a terminal, error
  text and exit codes, `--json` fields, REST paths and paging.

Three rules cover most of it:

- Judge a command by its exit code, never by stderr text: both tools write
  progress and notices to stderr on success, and some exit codes above 0 are a
  legitimate answer.
- Parse machine formats (`--porcelain -z`, `--format`, `--json`), never the
  English output.
- Anything that can prompt or open an editor gets its input up front: a flag,
  a file passed by path, or an environment variable set for that call only.

Both files name the version they were verified against. When it matters,
re-check with `gh <command> --help` or in a throwaway repository: tools change.

A repository's own instructions win wherever they differ from this, for
example a wrapper it requires instead of calling git or gh directly.

# gh behavior that breaks non-interactive use

Verified against gh 2.102 and its source (`cli/cli`, `pkg/cmd`). Re-check a flag
with `gh <command> --help` before leaning on it.

## Arguments

- A boolean flag takes its value only as `--flag=value`. Build
  `"--flag=$($v.ToString().ToLowerInvariant())"`.
- `--` ends the options (cobra). In a PowerShell array it is passed as written;
  only a direct function call swallows it. Operands that may start with a dash
  go after it (`gh search issues --json f -- -label:bug`), and so does
  everything else positional, so `--repo` goes before it.
- `gh gist clone <id> [<dir>] [-- <gitflags>]` and
  `gh repo fork [<repo>] [-- <gitflags>]`: there `--` hands the rest to git.
  Guard those operands by pattern against a leading dash instead.
- Slice flags (`--label strings`) are split on commas by cobra. A value with a
  comma goes in as a CSV-quoted field: wrapped in double quotes, with any
  inner double quote doubled.
- Search: each positional is one keyword; a keyword with a space becomes an
  exact `"phrase"`; qualifiers (`label:bug`) are separate arguments; a whole
  query in one argument is wrong for anything but a phrase.
- `gh api -F` (`--field`) types a value by its look (`true`, `123`, `@file`
  reads a file); outside text belongs in `-f` (`--raw-field`), which always
  sends a string.

## Not unattended

- `gh gist edit --desc x` alone opens `$EDITOR` (one file) or errors (several);
  `--desc ''` is ignored. Change a description with `PATCH gists/{id}`.
  `--add <f>` takes the positional file as the added file's content; `--remove`
  excludes `--add` and `--filename`; `--filename f <src>` replaces without an
  editor, and `-` reads stdin.
- `gh gist create` globs positional paths (`a[1].txt` is a pattern), reads `-`
  as stdin (a hang with no input), keys files by base name (two with one name
  collapse silently), and `--filename` names only stdin.
- `gh issue create` and `gh pr create` need `--title` and `--body` (or
  `--body-file`, or `--fill*`) without a terminal, and apply `--template` only
  along the prompt, editor and web paths, so `--template` does nothing
  non-interactively. `gh pr merge` needs `--merge`, `--squash` or `--rebase`
  when it cannot prompt.
- `gh pr create --dry-run` prints `Would have created a Pull Request with:` and
  `key:<TAB>value` lines, and may still push the branch.

## Output and errors

- `gh api` errors read `gh: <msg> (HTTP nnn)`. Other commands print
  `HTTP nnn: msg (url)` or `failed to get run: HTTP 404: ...`.
- `gh pr checks` writes its errors to stderr with an empty stdout and exits 1
  (`no pull requests found`, `Could not resolve to a PullRequest`,
  `no checks reported on the 'x' branch`); exit 1 also means failed checks, and
  8 means pending. Read stderr and the exit code together.
- `gh repo set-default --view` with no default exits 0 with the message on
  stderr; outside a repository it exits 1.
- `gh auth status --json` exits 0 even when logged out.
- `--json` fields can need a scope the token lacks (`projectItems` needs
  `read:project`) or be gone (`projectCards`), and either fails the whole call.
  Probe a default field list on a public repository
  (`gh <cmd> --json <fields> -R cli/cli`).
- gh trims a trailing line break from a secret or variable read on stdin, so
  the newline a pipe adds is harmless, and a value's own trailing line breaks
  are lost.
- `gh release create` and `upload` glob unlabeled asset arguments themselves
  and split `path#label` at the first `#`.

## REST

- A `#` in a path segment (a branch name for `rules/branches/{branch}`) starts
  a URL fragment: URL-encode it. List endpoints page at a default size that
  differs per endpoint: pass `?per_page=100` and paginate.

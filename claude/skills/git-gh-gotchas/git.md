# git behavior that breaks non-interactive use

Verified against git 2.47 in throwaway repositories. Re-check in a temporary
repository (`git init` in a temp folder) when it matters.

## Unattended

- The editor is `GIT_EDITOR`, then `core.editor`, then `VISUAL` (skipped when
  `TERM=dumb`), then `EDITOR`, so `-c core.editor=true` does not stop an editor
  when the caller has `GIT_EDITOR` set (common: `code --wait`), and
  `rebase --continue` launches it.
- Set these in the child process environment for each unattended call:
  `GIT_EDITOR=true`, `GIT_TERMINAL_PROMPT=0`, `GIT_ASKPASS` empty (it also wins
  over `core.askPass` and `SSH_ASKPASS`), and `GCM_INTERACTIVE=never`. When the
  call names its repository (`git -C <path>`) or needs none, also remove every
  repository variable (`GIT_DIR`, `GIT_INDEX_FILE`, `GIT_WORK_TREE` and the
  others): a hook run by an outer git with `--git-dir` sees `GIT_DIR` and
  `GIT_WORK_TREE`.
- None of that covers SSH host-key or passphrase prompts.
- To isolate a run from the user's and the system's configuration, set
  `GIT_CONFIG_GLOBAL` to a throwaway file and `GIT_CONFIG_NOSYSTEM=1`. On
  Windows `/dev/null` reads as empty, but a config write to it fails, or
  creates `\dev\null` where a `\dev` folder exists: a run that writes config
  uses a throwaway file.

## Operands

- An argument starting with `-` is an option: `log --output=<file>` writes a
  file, `clone --upload-pack=<cmd>` runs a command. Every ref, name, remote and
  URL operand must reject a leading dash. A path goes after `--`; a revision
  stays before it, because `git log -- main` filters by the path `main` instead
  of selecting that branch (`--end-of-options`, in git 2.24 and later, ends the
  options without that effect).
- A pathspec limit hides the other side of a rename (`R100 a b` becomes
  `A b`); filter after the listing.

## Reading state

- Parse porcelain: `status --porcelain -z -uall`, `ls-files -z`, or a
  `--format` with separators. The separator spelling depends on the command:
  `log` and `stash list` take `%x00` and `%x1f`; `for-each-ref` and `branch`
  take `%00` and `%1f` (the other spelling prints literally). Non-ASCII names
  come back octal-escaped unless `-z` or `core.quotePath=false` is used. Never
  parse English output (`remote show`): `ls-remote --symref` gives the default
  branch.
- `branch --format=%(refname:short)`, `for-each-ref`, `rev-parse --abbrev-ref`
  and `symbolic-ref --short` print `heads/main` when a tag shares the branch's
  name. Read `symbolic-ref HEAD` and strip `refs/heads/`. A detached HEAD is
  not a branch: `HEAD` is not a name to return.
- `rev-parse --is-inside-work-tree` prints `false` with exit 0 in a bare
  repository.
- `diff --quiet` and `merge-base --is-ancestor` exit 1 for a legitimate answer
  and above 1 for an error: a ref that does not exist is an error, not "changed"
  or "no".
- `diff` can be colored or start an external tool from user config: pass
  `--no-color --no-ext-diff`. `log` can read `log.showSignature` and
  `i18n.logOutputEncoding`.
- `stash` on a clean tree creates nothing, and a following `stash pop` then
  restores an older stash: check whether one was created.
- `rebase-apply` is shared by `am`, so it alone does not mean a rebase is under
  way.
- `pull` with neither `--rebase` nor `--no-rebase` follows `pull.rebase` and
  errors on a diverged branch since git 2.33.1: always pass one.
- `cherry-pick` has no `-q` or `--quiet`: passing one prints usage and exits 0
  without applying the commit.

## Streams

git writes progress to stderr on success. Do not treat stderr output as failure
and do not merge it into parsed output: read the two streams separately and
judge by the exit code.

---
name: handling-secrets
description: >-
  Keeps credentials out of chat, command output, logs, messages, tests,
  configuration files, commits and issues. Use before reading or printing
  anything that may hold a token, password or key (environment variables, git
  or gh configuration, process command lines, API responses), when a
  configuration file or a test needs a credential, and before pushing.
when_to_use: >-
  Trigger phrases: token, password, secret, credential, API key, gh auth,
  environment variables, .env, git config, remote url, mask, sentinel, leak,
  before I push.
---

# Handling secrets

Anything printed in a session (chat, tool output, a log, a sub-agent report, a
memory file, an issue, a pull request, a commit) has leaked, and a token that
appeared once must be revoked. The only fix is prevention.

## In a session

Never run a command whose job is to show a secret: `gh auth token`,
`gh auth status --show-token`, or reading a credential file (`.env`, gh's
`hosts.yml`, `~/.ssh/*`, `*.pfx`, `.npmrc`, `nuget.config`, a package
registry API key). A temporary `GH_CONFIG_DIR` does not help: gh falls back to
the system keyring.

Some commands reveal secrets as a side effect. Filter them first:

- `Get-ChildItem Env:`, `env`, `$env:*`: list names with
  `(Get-ChildItem Env:).Name`, and test presence with `[bool]$env:NAME`. Never
  print the value of a variable that may hold a secret, even to check it.
- `git config --list`, `--show-origin`, `git remote -v`, `git remote get-url`,
  and `--get` of `remote.<name>.url`, `http.*` or `credential.*`: values hold
  `user:token@host` and `http.extraheader`, and even `--name-only` can print a
  key that is itself a token. Read one known harmless key (`user.name`) with
  `--get`; for anything else print a count.
- A process's command line (`Win32_Process`, `ps`, `Get-Process | Format-List *`):
  arguments carry secrets. Print the Id and Name.
- API responses and failures (`gh api`, `Get-Error`, `$Error`, `Format-List *`
  of an error, `-Verbose` or `-Debug` of a web cmdlet, `Start-Transcript`,
  `Get-History`): select the properties you need.

Print counts, names, booleans and masked values; test for presence with
`Select-String -Quiet`. A probe that needs a token sets a fake one on the child
process only (`GH_TOKEN = 'SENTINEL_FAKE_TOKEN'`). Never put a secret in a
sub-agent brief, an issue, a pull request, a commit message, a memory file or a
file in any repository.

If one slips out: stop, tell the user at once what kind of secret it was and
where it appeared, do not repeat or copy it anywhere, and tell them to revoke
or rotate it. Then carry on.

## In configuration

A configuration file (an MCP server list, a settings file, a pipeline
definition) refers to a secret by environment variable, `${VAR}`, and never
holds the value. The value is set on the machine, by the user, outside any
file and outside the chat: ask them to set it, and do not offer to take it.

## In tests

Use a sentinel, never a real credential: `SENTINEL_SECRET_123`, or
`https://user:SENTINEL_SECRET_123@h.example/o/r` for a URL. Where the code
under test recognizes a token shape, build that fixture at run time
(`'ghp_' + ('A' * 36)`), so no literal in the repository matches a scanner's
pattern and trips push protection. A failing equality assertion prints both
sides, which is one more reason only sentinels are ever compared.

## Before pushing

Scan everything that would be published for token shapes and key blocks, from
the repository root: the working tree, what is staged, the commits to push and
their messages. The commits to push are those after the branch's upstream, or
after the default branch when it has none yet.

```powershell
$shapes = @(
    'gh[pousr]_[A-Za-z0-9]{36,}'
    'github_pat_[A-Za-z0-9_]{50,}'
    'AKIA[0-9A-Z]{16}'
    'xox[abprs]-[A-Za-z0-9-]{10,}'
    'oy2[a-z0-9]{43}'
    '-----BEGIN [A-Z ]*PRIVATE KEY[A-Z ]*-----'
)
$ere = '(^|[^A-Za-z0-9])(' + ($shapes -join '|') + ')'
$base = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
if ($LASTEXITCODE -ne 0) {
    $base = git symbolic-ref --short refs/remotes/origin/HEAD 2>$null
}
if ($LASTEXITCODE -ne 0) {
    throw 'No upstream and no origin/HEAD: set $base to the default branch.'
}
git grep -I -l -E --untracked -e $ere
git grep -I -l -E --cached -e $ere
foreach ($commit in @(git rev-list "$base..HEAD")) { git grep -I -l -E -e $ere $commit }
git log --format=%B "$base..HEAD" | Select-String -Pattern $ere -Quiet
```

`-l` prints only the location of a hit and `-Quiet` a yes or no, never the
matching text. `--untracked` covers tracked and untracked files but skips the
ignored ones, and git refuses to combine it with `--cached`, hence two calls.
An empty `$base` would turn the range into `HEAD..HEAD` and scan nothing, hence
the `throw`. A clone or worktree often has no `origin/HEAD`:
`git remote set-head origin --auto` sets it, or name the default branch
yourself. Push only when the user asked for it.

## Where a repository differs

A repository's own instructions win wherever they differ from this, for
example its own masking helpers or secret scanner.

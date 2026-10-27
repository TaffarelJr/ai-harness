---
name: running-powershell
description: >-
  How to run commands through the PowerShell and Bash tools without lost
  quoting, leaked environment, wrong line endings or BOMs, runs that hang or
  end unnoticed, a real tool or dialog opening, or a command the guard hook
  denies. Use before running any command, script or test run, after writing a
  file with the Write tool, and when a command did nothing, was denied or
  behaved unexpectedly.
when_to_use: >-
  Trigger phrases: run in the background, command timed out, hung, pwsh -File,
  Start-Process, set an environment variable, output too long, line endings,
  BOM, git add failed, analyzer hangs, blocked by hook, commit message.
---

# Running commands

Use the PowerShell tool for PowerShell (pwsh 7, `C:\` paths). Use the Bash tool
only for POSIX scripts (Git Bash, `/c/...` paths), and never mix their syntax.
Do not call `python3` in Git Bash: it can be a Store stub that does nothing.

## Each call stands alone

- A call may start in any directory and sees no variable, function or module
  from an earlier call. Use absolute paths (`git -C <path>`) and import by
  path; a script that needs a location sets it itself.
- An environment variable set in a call reaches every process that call starts
  afterwards, so a leaked `GIT_AUTHOR_NAME` changes the author every later git
  call records. Prefer a value for the child only
  (`ProcessStartInfo.Environment`). Restore anything else in `finally` with
  `$env:NAME = $previous` (`$null` removes it), and never leave `GIT_*`,
  `GH_*` or `PSModulePath` changed.

## Quoting, arguments, exit codes

- A script longer than one line, or with nested quotes, goes in a file (Write
  tool) and runs as `pwsh -NoProfile -File <absolute path>`. Do not build long
  `-Command "..."` strings.
- `Start-Process` does not quote the elements of `-ArgumentList`. A `-Command`
  text with spaces or quotes is split and parsed again, so
  `Add-Content 'log' "done (exit 0)"` became a call to `exit`. A `-File` path
  with a space needs its own quotes. Prefer the tool's `run_in_background` to
  `Start-Process`.
- `pwsh -File x.ps1 -Name a, b` binds the string `a,` plus a stray `b`, and
  `-Name a,b` is the single value `a,b`. Pass one value per run, have the
  script split its own string, or join with `[IO.Path]::PathSeparator` and
  split inside.
- `exit` ends only the script it is in. Read `$LASTEXITCODE` after `pwsh -File`;
  a script that returns without `exit` leaves a stale value under `&`.
- The tool may refuse a recursive `Remove-Item` on a variable path inside an
  inline here-string. Write cleanup as a script file and read it before
  running it.

## The command guard

My PreToolUse hook reads the text of every Bash and PowerShell command, without
parsing it, and denies:

- a force-push, a branch deletion or a bulk push (`--mirror`, `--prune`,
  `--force --all`) aimed at the default branch or at no named branch, and
  force-deleting or force-renaming the default branch;
- `gh pr merge`, and a `gh api` call that merges a pull request or changes a
  ref;
- anything that hides what runs: an encoded PowerShell invocation,
  `Invoke-Expression`, `eval`, piping into `xargs git`, a git or gh alias, a
  `GIT_CONFIG_*` assignment, `Start-Process` launching git, or a long base64
  blob beside a git or gh command.

It matches words anywhere in the text, so it over-blocks on purpose. A commit
message or pull request body that merely mentions such a command is denied as
if it ran it, and so is any command where `pwsh` or `powershell` is followed,
in the same command, by `-e`, `-ec`, `-enc` or `-EncodedCommand` (an
`-ExecutionPolicy` flag is fine). Prose goes in a file passed by path: write it
with the Write tool,
then `git commit -F <file>`, `gh pr create --body-file <file>`,
`gh issue comment --body-file <file>`. Never inline, and never reworded to
slip past the scan. A denial says what to do instead; when the command is
really needed, hand it to me to run.

## Long-running work

- The foreground waits 2 minutes by default and 10 at most; a longer command is
  moved to the background. Start a test run, and the analyzer, with
  `run_in_background` and wait for the notification: do not poll its output
  and do not `sleep`. To wait on several, run one background command that
  loops until a marker line appears in a log.
- `Start-Process` sends no completion notice, even with `-PassThru`, and shows
  no error when hidden. Use it only for work you will check: log to a file, end
  the script with a marker line, and look for the marker, not the process list.
- A background task that "completed" may only mean its launcher ended. Read the
  log for the result.
- PSScriptAnalyzer takes seconds a file alone and minutes under load, can hang,
  and sometimes throws a null-reference error on a folder run. Run it file by
  file, as a background task with a timeout: in the Bash tool,
  `timeout 600 pwsh -NoProfile -File <script>`.

## Files, line endings and BOMs

- Check `.editorconfig` (`end_of_line`, `charset`) and `.gitattributes`
  (`eol=`) for what a file should be. Otherwise keep what the file already
  has, and give a new file what its neighbors have: CRLF on Windows, no BOM,
  unless the repository uses one (a C# repository may).
- Edit keeps a file's own endings and gives new lines the same. The Write tool
  writes LF, so convert after every Write and verify by bytes, not by eye.
- `git add` stops with "LF would be replaced by CRLF" for an LF-only file when
  `core.safecrlf` and `core.autocrlf` are on. Normalize the file; do not switch
  the check off, except for a throwaway snapshot.
- After scripts or agents run, `git status --short` shows what they left.

```powershell
$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes($path)
$bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$skip = $bom ? 3 : 0
$text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes, $skip, $bytes.Length - $skip)
$text = $text -replace "`r?`n", "`r`n"
[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($bom))
```

`$path` must be absolute, because .NET resolves a relative path against the
process directory. The BOM is read from the bytes: `ReadAllText` strips one
silently, so the text alone cannot tell. The strict decoder throws on
non-UTF-8 bytes, and with the preference at `Stop` that ends the script before
anything is written. For an LF file, replace with `` "`n" `` instead. When
Write replaced a file that had a BOM, the bytes no longer show it: decide from
`charset = utf-8-bom` or a sibling file, and set `$bom` yourself. Use it only
on UTF-8 text files.

## Real tools and the desktop

- A probe never reaches a real tool or the desktop. For gh, use
  `gh <command> --help`, gh's source, or a stub placed first on `PATH`; for
  git, a throwaway repository in a temp folder. A real tool can open a dialog
  (an SSH host-key prompt, a "not a program" box) that blocks the run with no
  output.
- Never launch a GUI application (VS Code), run an installer, or call
  `Install-Module` or `Install-PSResource` from a probe.
- Never run `reset --hard`, `checkout .`, `checkout -- <path>`, `restore`,
  `stash`, `clean`, `branch -D` (except on your own temporary branch) or a
  force-push (except to update an open pull request's branch) without my
  go-ahead: uncommitted work cannot be recovered. git writes progress to
  stderr on success: judge a command by `$LASTEXITCODE`, not by stderr text.

## Output

- Cap output before it prints: `Select-Object -First 20`, counts, names. Write a
  large result to a file and Read the part you need.
- Anything that might hold a secret: `handling-secrets` first.

## Where a repository differs

A repository's own instructions win wherever they differ from this: its test
runner, its helpers for running tools, its line-ending and encoding rules.

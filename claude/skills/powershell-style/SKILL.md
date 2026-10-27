---
name: powershell-style
description: >-
  Formatting and idiom rules for any PowerShell file (.ps1, .psm1, .psd1):
  #Requires, encoding, naming, wrapping, braces, literals, help,
  comments, output, analyzer suppressions. Use when writing, editing or
  reviewing any PowerShell file in any repository, even a short script.
when_to_use: >-
  Trigger phrases: write a script, PSScriptAnalyzer warning, approved verb,
  line length, formatting, comment-based help, is this idiomatic.
---

# PowerShell style

How I write PowerShell. Traps that give a wrong answer are in
`powershell-pitfalls`. Where the surrounding file does something these rules
do not mention, match it.

## Files

- A file that can be run or imported alone (a script, a module's root `.psm1`,
  a test file) opens with `#Requires -Version 7.4`, unless the repository pins
  another version. A file reached only by dot-sourcing does not need one.
- `using namespace <Namespace>` comes after `#Requires` and comments, only in a
  file that uses such a type (`[List[string]]` for `System.Collections.Generic`).
  Accelerated types (`[Math]`, `[regex]`) never need one.
- A module's root `.psm1` sets `Set-StrictMode -Version Latest` and
  `$ErrorActionPreference = 'Stop'`: strict mode is never inherited, and a
  caller's local preference does not reach module scope. Each exported function
  pins the preference again, because a caller's `-ErrorAction` becomes its own.
- Files are UTF-8 without a BOM, with CRLF line endings on Windows;
  `.editorconfig` and `.gitattributes` win where they say otherwise.
  PowerShell 7 reads BOM-less UTF-8 correctly; the BOM only served Windows
  PowerShell 5.1. So the analyzer settings exclude
  `PSUseBOMForUnicodeEncodedFile`, and box-drawing characters and emoji in
  source are fine.

## Names

- `Verb-Noun` with an approved verb (`Get-Verb`) and no decorative prefix on
  the noun: `Get-FileHash`, not `Get-XyFileHash`.
- Parameters are PascalCase singular nouns and reuse the common names (`Path`,
  `Name`, `Force`, `PassThru`) rather than inventing synonyms.

## Wrapping

- The width (target, allowance and hard limit) is my user-level rule and is
  not repeated here. Help text stays within the target.
- A call too long for one line breaks at parameter boundaries, one parameter
  per continuation line, or takes a splatted hashtable.
- **One command per statement.** Do not chain different operations across
  continuation lines: assign the first result to a variable, then filter or
  sort it in the next statement, and hoist a long argument array into a
  variable. A single query (filter, project or aggregate in one coherent
  pipeline, each `|` ending its line, assigned or returned as one expression)
  reads fine at two or three stages.

## Blocks and literals

- Spread `if`/`elseif`/`else` and `try`/`catch`/`finally` across lines: the
  condition and its brace on one line, the body indented, the closing brace
  alone. Only a short single-expression value assignment may stay compact:
  `$body = if ($cond) { $a } else { $b }`.
- Each parameter attribute gets its own line; the type and `$Name` share the
  last one:

  ```powershell
  [Parameter(Mandatory)]
  [ValidatePattern('\S')]
  [string]$From,
  ```

- Write the accelerator as `[PSCustomObject]`, not `[pscustomobject]`. Once it
  or a hashtable has more than one entry, each property gets its own line so
  the names line up; a single-entry or empty literal stays on one line. A plain
  array of simple values (`@('.git', 'bin', 'obj')`) wraps for length only.
- `[CmdletBinding()]` goes on its own line above `param`. Without it a
  misspelled named parameter is ignored and `-ErrorAction` is not accepted.

## Help

- An internal script or private function gets minimal help: `.SYNOPSIS`, plus
  `.DESCRIPTION` and `.PARAMETER` where they add something the names do not.
- Anything published as an API (an exported function, a script others call)
  gets full help: `.SYNOPSIS`, `.DESCRIPTION`, every `.PARAMETER`, `.INPUTS`,
  `.OUTPUTS` and at least one `.EXAMPLE`.

## Idiom

- No comments by default. A comment states a non-obvious reason on exactly the
  code it explains: never a restatement of the code, an architecture note, or
  the history of a change. Architecture goes in the README, history in the
  commit.
- `-LiteralPath` for a filesystem cmdlet on a variable path, never `-Path`, so a
  wildcard character in a name is not a pattern. `New-Item` and `Join-Path`
  have no `-LiteralPath`; use `-Path` there, and pass `Import-Module` the path
  positionally.
- Put `$null` on the left of `-eq` and `-ne`.
- Write `Where-Object` comparison parameters in their exact case: `-EQ`, `-NE`,
  `-GT`, `-Like`, `-Match`, `-In` (the analyzer's `PSUseCorrectCasing` flags
  `Where-Object Name -eq 'x'`).
- Prefer `[Parameter(Mandatory)]` to `[ValidateNotNullOrEmpty()]`. Add
  `[ValidatePattern('\S')]` only to also reject whitespace, and
  `[AllowEmptyString()]` only when blank is legal.
- Output streams: write a list of results one item at a time
  (`return $results`), and callers that need an array wrap the call, `@(...)`.
  Never `return , $x` to protect a list. The single exception is a function
  whose one value is itself an array: it keeps `return , $array`, and a public
  one offers `-NoEnumerate`, as `ConvertFrom-Json` does.
- Temp paths come from `[IO.Path]::GetTempPath()`. Join with the multi-segment
  `Join-Path $a 'b' 'c'` and no drive letters, so a path works on Linux and
  macOS; forward slashes inside a segment are fine.

## Analyzer

- A settings file switches a rule off only when most files break it, and says
  why. A function that has to break a rule suppresses it where it breaks it,
  with a true one-line reason, after its `[CmdletBinding()]` (a script carries
  it on a `param()` at the top):

  ```powershell
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
      'PSAvoidUsingWriteHost',
      '',
      Justification = 'Writing to the host is what this script is for.')]
  ```

- A suppression is for a rule that is wrong for that code, not one that is
  inconvenient: fix a finding at its cause.

## Where a repository differs

A repository's own instructions, `.editorconfig`, `.gitattributes` and analyzer
settings win wherever they differ from this.

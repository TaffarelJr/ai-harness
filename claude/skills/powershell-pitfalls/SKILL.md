---
name: powershell-pitfalls
description: >-
  PowerShell traps that give a wrong answer without an error, or a baffling one,
  each with its fix: quoting, null and arrays, dictionaries, comparison case,
  parameter binding, error preferences, module scope, paths, encodings. Use
  when something returned null or the wrong value, an error was skipped or a
  parameter bound to text, or before writing code that crosses one of these
  edges.
when_to_use: >-
  Trigger phrases: returned null, silently wrong, expected true got true, error
  skipped, bound to text, only the last item, wrong folder, mojibake.
---

# PowerShell pitfalls

Each entry says what goes wrong and what to do. Formatting rules are in
`powershell-style`.

## Syntax

- **`"$name: text"`** is a syntax error (a variable followed by a colon is a
  drive-qualified name). Write `"${name}: text"`.
- **`$list.Add("{0}-{1}" -f $a, $b)`** passes two arguments, because the comma
  separates method arguments, and fails with "Error formatting a string".
  Parenthesize the format expression: `$list.Add(("{0}-{1}" -f $a, $b))`.
- **A native-command argument that mixes text and an expression** is not one
  argument: `-F id=$item.thread` expands only `$item` and leaves `.thread` as
  text, and `-F number=($n)` is split into two arguments. Build the whole
  argument as one string: `"id=$($item.thread)"`, `"number=$n"`.
- **`-like` and `-match` patterns** treat `[` and `*` as pattern characters: a
  `-like '| [x]*'` matched a table header. Escape literal text with
  `[WildcardPattern]::Escape()` for `-like` and `[regex]::Escape()` for
  `-match` (the first does not escape `.` or `(`).
- **`$` in a regex** also matches before a final LF; anchor the very end with
  `\z`.

## Null, arrays and output

- **`$value -eq $null`** filters when `$value` is an array and returns the
  matching elements: `@(1, $null) -eq $null` is falsy but
  `@($null, $null) -eq $null` is truthy. Write `$null -eq $value`. Comparing
  two arrays with `-eq` never matches either: compare element by element.
- **`-eq`, `-ne`, `-like` and `-match` ignore case.** `$after -ne $before` is
  false for a casing-only change. Use `-ceq` and `-cne`, or
  `[string]::Equals($a, $b, 'Ordinal')`, when case counts. The key lookups of
  `@{}` and `[ordered]@{}` ignore case too; `[hashtable]::new()` and
  `Dictionary[string, object]` do not.
- **String comparison also skips ignorable code points.** `-eq`, `-ceq`,
  `switch` and `Compare-Object` compare by culture rules, under which a byte
  order mark (U+FEFF) or a soft hyphen counts for nothing: `'x' -ceq "`u{FEFF}x"`
  is true, so a test cannot tell a value with a stray BOM from one without.
  Compare with `[string]::Equals($a, $b, 'Ordinal')`, which an array's
  `.Contains()` already uses, and build a test harness's equality on it.
- **`ConvertFrom-Json` fails on keys that differ only in case** ("contains
  keys with different casing"), because it builds a case-insensitive object;
  `~/.claude.json` holds both `c:/x` and `C:/x` project paths. Pass
  `-AsHashtable`, whose keys are case-sensitive, and index with the exact key.
- **A `string[]` interpolated into a string** joins on `$OFS` (one space), so a
  captured multi-line output collapses to one line. Join with
  `-join [Environment]::NewLine` first.
- **Inner arrays flatten.** An array subexpression unrolls what each statement
  in it emits, so `@( @('a', 'b') @('c', 'd') )` on separate lines is four
  strings, and a loop meant to see pairs sees strings: `$pair[0]` is a first
  character, and a `Replace($pair[0], $pair[1])` written for pairs rewrites
  single characters. A table of pairs is one of hashtables
  (`@{ Old = 'a'; New = 'b' }`), or the inner arrays are separated by commas
  on one line; check `$pair.Count` before trusting the shape.
- **A function that emits zero or one item** gives `$null` or the bare item
  when assigned: `$one[0]` on a single string is its first character. Wrap the
  call, `@(Get-Foo)`. `return $null` emits a real `$null` item, so
  `@(Get-Foo).Count` is 1; use a bare `return`. Never `return , $x` to protect
  a list: a direct pipe then sees one merged item. A function whose one value
  is itself an array is the exception: it keeps `return , $array`, and a public
  one offers `-NoEnumerate`.
- **A hashtable or dictionary read with `.Count`, `.Keys` or `.Values`**
  returns the value of a key with that name (as does any other member, such as
  `.IsReadOnly`): `@{ Count = 7; Name = 'a' }.Count` is 7. When the keys come
  from a caller or from data, use `.PSBase.Count`, `.PSBase.Keys` and
  `.PSBase.Values`. Method calls (`.Contains()`) are safe.
- **Many cmdlet results are PSObject-wrapped** (`Test-Path`, `Get-Date`,
  `Join-Path`, `Resolve-Path`, `Get-Content` lines), so `Test-Path $p` answers
  true to `-is [pscustomobject]`. Unwrap with `.psobject.BaseObject` before any
  type-based branch. Tell: a failure that prints "expected true, got true".
- **`Write-Host`** writes to the information stream (capture with `6>`), not
  standard output, and `Out-Null` does not discard it.
- **`.ToString()`, `-f` and `[double]::Parse`** follow the current culture;
  interpolation and casts are invariant. Pass `[CultureInfo]::InvariantCulture`
  for anything stored, compared or sent to a tool.

## Parameters and the pipeline

- **`[Parameter(Mandatory)]` rejects `''`, `$null` and an array holding an empty
  string** for `[string]` and `[string[]]`, even though the array is
  non-empty. Add `[AllowEmptyString()]` (or `[AllowEmptyCollection()]`) at
  every layer the value crosses, or the failure moves one call down. An
  `[object]` parameter accepts `''`: validate it in the resolver.
- **A `[string]` or `[string[]]` parameter with `ValueFromPipeline` binds a piped
  object as its text** (`@{Number=7; Title=x}`) when the property is not
  already a string, and adding `ValueFromPipelineByPropertyName` does not
  change that: by-value binding wins for the whole object. Take `[object]` and
  resolve it. Test with objects whose property is numeric.
- **`ValueFromPipeline` without a `process` block** runs only for the last
  record.
- **An empty pipeline is not "everything"**: decide "was anything given" from
  `$PSBoundParameters`, and in `begin` or `end` from
  `$MyInvocation.ExpectingInput`, not from the value.
- **`$null.Property` or a missing property** throws under
  `Set-StrictMode -Version Latest`. `if ($x)` is no guard (it skips `0`, `''`
  and `$false`, and a missing property on a non-null object still throws):
  test `$null -ne $x`, or `$object.PSObject.Properties['Name']`.
- **A command operand that starts with `-`** is an option. Validate with
  `'^(?!-)'`, and pass it after `--` only where the subcommand reads it as a
  plain operand: `git log -- main` makes `main` a path.
- **`$null` passed to a .NET `[string]` parameter arrives as `''`**:
  `[Queue[string]]::new().Enqueue($null)` stores an empty string, and a method
  that treats null and empty differently never sees the null. Pass
  `[NullString]::Value` where a real null is meant.
- **`Position` belongs to each `[Parameter()]` attribute**, not to the
  parameter. A parameter in two sets with `Position = 0` on one attribute is
  named-only in the other set, so a positional call that resolves to that set
  fails with "A positional parameter cannot be found". Repeat `Position` on
  every attribute that should accept it.

## Errors and preferences

- **A caller's `-ErrorAction SilentlyContinue` or `Ignore`** becomes
  `$ErrorActionPreference` inside the function, so a cmdlet that fails without
  throwing is ignored. Pin `'Stop'` first in the function.
- **A module's `$ErrorActionPreference` does not reach another module's
  functions.** `Install-Module` fails without throwing; pass
  `-ErrorAction Stop` on the call.
- **A plain `throw` is skipped** under `-ErrorAction SilentlyContinue`, so the
  function carries on to the change. `ThrowTerminatingError` is not, but
  inside a private helper it stops only the helper's call. Keep `throw` in
  helpers, and wrap each public function's body in a `try` whose `catch` calls
  `$PSCmdlet.ThrowTerminatingError($_)`; a bare `throw` in that `catch` is
  skipped again.
- **Inside a `try` or `catch`, a terminating error becomes an exception**, so
  the difference between a plain `throw` and `ThrowTerminatingError`
  disappears. A test of "does not carry on under `SilentlyContinue`" must run
  the call outside every handler: a fresh runspace or child process.

## Modules and scope

- **A call into another module resolves through the global scope**, so a
  later-loaded command with the same name wins. Import each dependency into the
  module's own scope (`Import-Module -ModuleInfo`, not `-Global`); a qualified
  call `Module\Command` is also safe.
- **`-WhatIf` does not cross a module boundary**, so a call into another
  module's changing function belongs inside your own `ShouldProcess` guard. A
  built-in cmdlet inside the module does inherit `$WhatIfPreference` and only
  prints `What if:`, so a read that must run under `-WhatIf` gets
  `-WhatIf:$false -Confirm:$false`. A confirmation prompt throws in a
  non-interactive host: never set `ConfirmImpact`.
- **A caller's `$VerbosePreference` does not reach a module function either.**
  Copying it with `$PSCmdlet.GetVariableValue('VerbosePreference')` at the top
  overwrites that call's own `-Verbose`; guard it with
  `if (-not $PSBoundParameters.ContainsKey('Verbose'))`.
- **`Get-Command Foo`** can resolve an alias (a function `R` resolved to `r`,
  `Invoke-History`). Use `-Module`, or enumerate `$module.ExportedFunctions`.
- **`Get-Module -ListAvailable`** finds a module anywhere below a `PSModulePath`
  folder. A test's "not on the path" module goes in a sibling folder, not a
  subfolder.
- **`New-Variable -Option Constant`** can never be removed, so a second
  `Import-Module -Force` fails and leaves the module without its functions.
  Use `-Option ReadOnly`, which `Remove-Module -Force` clears.
- **A type literal can name an assembly a fresh `pwsh` has not loaded yet.** A
  long-lived session may have loaded it already, so only a fresh process shows
  the failure: test it in a child `pwsh`.

## Paths, files and text

- **.NET resolves a relative path against the process's directory**, which
  `Set-Location` does not change, so `[File]::ReadAllText('rel')` reads the
  wrong file. Resolve first with
  `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath`,
  also for `ProcessStartInfo.WorkingDirectory`.
- **`Split-Path -Parent` returns backslashes** on Windows, and an embedded
  backslash in a joined path breaks Linux and macOS. Use the multi-segment
  `Join-Path $a 'b' 'c'`.
- **Lenient decoding is permanent**: Latin-1 bytes become U+FFFD and the
  original is gone. Decode strictly (`[Text.UTF8Encoding]::new($false, $true)`).
- **`(?m)$` does not match before CRLF**, and `.` and `\s` match `\r`. Use
  `[^\r\n]`, `[ \t]` and `\r?$`, or a replace turns the file to LF.
- **`[Environment]::SetEnvironmentVariable(name, '')`** sets an empty value on
  .NET 9 (PowerShell 7.5 and later) and deleted it before; pass
  `[NullString]::Value`, or use `$env:NAME = $null`, to delete.
- **A native command's stderr** carries progress even on success. Judge by
  `$LASTEXITCODE`, reset `$global:LASTEXITCODE` after tolerating a failure, and
  pass arguments as an array.

## Help and analyzer

- **A help line starting with a dot-word** (`.NET`, `.psm1`) is read as a
  keyword and drops the whole block. Help directly after `#Requires` or another
  comment is ignored; put a blank line between. A `.PARAMETER` for a missing
  parameter is silently dropped.
- **PSScriptAnalyzer** can throw a null-reference error on a folder run, and is
  slow and can hang under load. The crash is not a finding: run it file by
  file.

## Where a repository differs

A repository's own instructions win wherever they differ from this; a trap it
documents with a different fix takes its fix.

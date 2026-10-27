#Requires -Version 7.4

<#
.SYNOPSIS
    Denies a shell command that force-pushes, deletes a branch or remote ref,
    merges a pull request, or hides any of those behind an alias or an encoder.
.DESCRIPTION
    A Claude Code PreToolUse hook for the Bash and PowerShell tools. It reads
    the hook input from standard input and scans tool_input.command as raw
    text: it does not parse shell structure, because a tokenizer loses to
    quoting, continuations, substitution, brace expansion and nested shells.
    After joining line continuations it matches the dangerous shapes with
    regular expressions and deliberately over-blocks; the deny reason tells
    the agent to run the command itself so a person can see it. A force-push
    or a branch delete is allowed to a named feature branch and denied for
    the default branch (main or master) or when no branch is named. Setting
    the environment variable AI_HARNESS_ALLOW_HISTORY_REWRITE to 1 or true in
    the hook's own environment allows force-pushes and branch deletions to any
    branch for that session (merging a pull request stays denied). A command
    it refuses is denied as JSON on standard output. Anything else is left to
    the normal permission flow. It never reaches the network, and it fails
    closed: an unexpected error blocks the call (exit 2).
.INPUTS
    System.String. The hook input JSON, on standard input.
.OUTPUTS
    None, or the deny decision as JSON on standard output.
.EXAMPLE
    $hookInput = '{"tool_name":"Bash","tool_input":{"command":"git push -f"}}'
    $hookInput | pwsh -NoProfile -File ./Block-DangerousGit.ps1

    Prints a deny decision for the force-push.
.LINK
    https://github.com/TaffarelJr/ai-harness/blob/main/README.md
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Any {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [string[]]$Pattern
    )

    foreach ($one in $Pattern) {
        if ([regex]::IsMatch($Text, $one)) {
            return $true
        }
    }

    return $false
}

function Get-DestinationBranch {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Refspec
    )

    $dest = $Refspec.TrimStart('+')
    if ($dest.Contains(':')) {
        $dest = $dest.Substring($dest.LastIndexOf(':') + 1)
    }

    if ($dest -match '^refs/heads/') {
        $dest = $dest.Substring('refs/heads/'.Length)
    }

    return $dest
}

function Get-PushDestination {
    <#
    .SYNOPSIS
        Returns the branches a push names, and whether any is the default.
    .DESCRIPTION
        Splits the text into rough shell segments, finds each push or
        send-pack, and reads the destination of each refspec: the part after a
        colon, else the refspec itself, with a leading + and a refs/heads/
        prefix stripped. The first bare operand is the remote; the rest are
        refspecs. A bare HEAD or an empty destination counts as unnamed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $raw = [System.Collections.Generic.List[string]]::new()
    foreach ($segment in [regex]::Split($Text, '&&|\|\||[;&|\r\n(){}]')) {
        $tokens = @($segment -split '\s+' | Where-Object { $_ -ne '' })
        $verb = -1
        for ($i = 0; $i -lt $tokens.Count; $i++) {
            if ($tokens[$i] -ceq 'push' -or $tokens[$i] -ceq 'send-pack') {
                $verb = $i
                break
            }
        }

        if ($verb -lt 0) {
            continue
        }

        $bare = [System.Collections.Generic.List[string]]::new()
        for ($i = $verb + 1; $i -lt $tokens.Count; $i++) {
            $token = $tokens[$i]
            if ($token.StartsWith('-')) {
                continue
            }

            if ($token.StartsWith('+') -or $token.Contains(':')) {
                $raw.Add((Get-DestinationBranch -Refspec $token))
            }
            else {
                $bare.Add($token)
            }
        }

        for ($i = 1; $i -lt $bare.Count; $i++) {
            $raw.Add((Get-DestinationBranch -Refspec $bare[$i]))
        }
    }

    $named = [System.Collections.Generic.List[string]]::new()
    $hasDefault = $false
    foreach ($dest in $raw) {
        if ([string]::IsNullOrEmpty($dest) -or $dest -ieq 'HEAD') {
            continue
        }

        $named.Add($dest)
        if ($dest -imatch '^(?:main|master)$') {
            $hasDefault = $true
        }
    }

    return [PSCustomObject]@{ Named = $named; HasDefault = $hasDefault }
}

function Get-DenyReason {
    <#
    .SYNOPSIS
        Returns the reason to deny a command, or nothing to allow it.
    .DESCRIPTION
        Every test is an independent regex over the whole text, so the work
        is linear in the command's length. The tool names git and gh are
        matched without case; git subcommands are matched with case, as git
        requires them. A force-push or a branch delete is allowed to a named
        feature branch and denied for the default branch (main or master) or
        when no branch is named; with -Override both are allowed anyway.
    .PARAMETER Text
        The command, with line continuations already joined.
    .PARAMETER Override
        Allow force-pushes and branch deletions to any branch (gh pr merge and
        the api merge forms are still denied).
    .OUTPUTS
        System.String. The reason, or nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Override
    )

    $runItYourself = 'run it yourself if you mean to, so a person can see it'

    # A push-like verb (push or send-pack, however the tool name is obscured).
    if (Test-Any -Text $Text -Pattern @('\bpush\b', '\bsend-pack\b')) {
        $force = Test-Any -Text $Text -Pattern @(
            '--force',                      # --force, --force-with-lease[=val], --force-if-includes, --force-w/-i
            '(?:^|\s)-[a-z]*f[a-z]*\b',     # a short-flag cluster carrying f
            '(?:^|\s)\+[\w./:-]+'           # a +refspec force
        )
        $delete = Test-Any -Text $Text -Pattern @(
            '--del[a-z]*',                  # --delete and every abbreviation down to --del
            '(?:^|\s)-[a-z]*d[a-z]*\b',     # a short-flag cluster carrying d
            '(?:^|\s):[\w./-]+'             # a :branch delete refspec
        )
        $bulk = Test-Any -Text $Text -Pattern @('--mirror', '--prune\w*')
        $all = $force -and (Test-Any -Text $Text -Pattern @('(?:^|\s)--all\b'))
        if (($force -or $delete -or $bulk -or $all) -and -not $Override) {
            if ($bulk -or $all) {
                return 'this pushes in bulk (--mirror/--prune/--all) and can rewrite many branches; ' +
                    'push the one branch you mean'
            }

            $dest = Get-PushDestination -Text $Text
            if ($dest.Named.Count -eq 0) {
                return 'name the branch, e.g. `git push --force-with-lease origin <branch>`; ' +
                    'force-pushing the default branch is not allowed'
            }

            if ($dest.HasDefault) {
                return 'force-pushing or deleting the default branch (main or master) is not allowed; ' +
                    'push to a feature branch instead'
            }
        }
    }

    # git branch that force-deletes or force-renames main or master. Judged
    # within one command segment: a PowerShell -Depth or -Module elsewhere in
    # a script, plus the words in a string, must not count.
    if (-not $Override) {
        foreach ($segment in [regex]::Split($Text, '&&|\|\||[;&|\r\n(){}]')) {
            if (-not [regex]::IsMatch($segment, '\bbranch\b') -or
                -not (Test-Any -Text $segment -Pattern @('\b(?:refs/heads/)?(?:main|master)\b'))) {
                continue
            }

            $branchDestructive = Test-Any -Text $segment -Pattern @('(?:^|\s)-[A-Za-z]*[DM][A-Za-z]*\b')
            $branchForceCombo = (Test-Any -Text $segment -Pattern @('--delete', '(?:^|\s)-[a-z]*d[a-z]*\b')) -and
                (Test-Any -Text $segment -Pattern @('--force', '(?:^|\s)-[a-z]*f[a-z]*\b'))
            if ($branchDestructive -or $branchForceCombo) {
                return 'force-deleting or force-renaming the default branch (main or master) is not allowed'
            }
        }
    }

    # gh pr merge, in either word order, with or without -R repo flags.
    $ghPresent = [regex]::IsMatch($Text, '(?i)\bgh\b')
    if ($ghPresent -and
        [regex]::IsMatch($Text, '\bpr\b') -and
        [regex]::IsMatch($Text, '\bmerge\b')) {
        return 'merging a pull request is a person''s decision; merge it yourself'
    }

    if ($ghPresent -and [regex]::IsMatch($Text, '\bapi\b')) {
        $mutating = Test-Any -Text $Text -Pattern @(
            '(?i)(?:-X|--method)\s+["'']?(?:DELETE|PATCH|PUT|POST)',
            '(?i)(?:-X|--method)["'']?=["'']?(?:DELETE|PATCH|PUT|POST)'
        )
        $refOrMerge = Test-Any -Text $Text -Pattern @('git/refs', 'pulls/\S+/merge')
        if ($mutating -and $refOrMerge) {
            return "this gh api call mutates a ref or merges a pull request; $runItYourself"
        }

        if ([regex]::IsMatch($Text, '\bgraphql\b') -and
            (Test-Any -Text $Text -Pattern @('mergePullRequest', '=@', '(?i)(?:-F|--field|-f|--raw-field)\s+\S*@'))) {
            return "this gh api graphql call can mutate (a mutation name or a query from a file); $runItYourself"
        }
    }

    if ($ghPresent -and [regex]::IsMatch($Text, '\balias\b') -and [regex]::IsMatch($Text, '\bset\b')) {
        return 'gh alias set can hide a command behind an alias; set it yourself'
    }

    # Obfuscation and indirection: run the real command in the open instead.
    $openUp = 'run the command directly, in the open, so a person can see what it does'
    if (Test-Any -Text $Text -Pattern @('(?i)\bgit\b[\s\S]{0,40}?-c\s*["'']?alias\.', 'alias\.[\w-]+\s*=')) {
        return "this hides a command inside a git alias; $openUp"
    }

    if ([regex]::IsMatch($Text, 'GIT_CONFIG_[A-Z0-9_]*\s*=')) {
        return "a GIT_CONFIG_* assignment can rewrite what a git command does; $openUp"
    }

    if (Test-Any -Text $Text -Pattern @('(?i)\beval\b')) {
        return "eval hides what runs; $openUp"
    }

    if (Test-Any -Text $Text -Pattern @('(?i)\bxargs\b[\s\S]*\bgit\b', '(?i)\bgit\b[\s\S]*\|\s*xargs')) {
        return "piping into xargs git hides the real command; $openUp"
    }

    if (Test-Any -Text $Text -Pattern @('(?i)\b(?:invoke-expression|iex)\b')) {
        return "Invoke-Expression hides what runs; $openUp"
    }

    if (Test-Any -Text $Text -Pattern @('(?i)\b(?:start-process|saps)\b[\s\S]{0,40}?git')) {
        return "launching git through Start-Process hides its arguments; $openUp"
    }

    # pwsh/powershell -EncodedCommand (and its -e/-ec/-enc short forms) hides the script in base64.
    # The flag must follow the shell name in the same segment: a bare `set -e` elsewhere is not it.
    $encodedShell = '(?i)\b(?:pwsh|powershell)(?:\.exe)?\b[^;&|\r\n]*\s-e(?:c|nc|ncodedcommand)?\b'
    if (Test-Any -Text $Text -Pattern @($encodedShell)) {
        return "an encoded PowerShell command hides what runs; pass the script as plain text instead"
    }

    # A long base64-looking blob next to a git or gh command, e.g. a smuggled script.
    if (Test-Any -Text $Text -Pattern @('(?i)\bgit\b', '(?i)\bgh\b')) {
        foreach ($blob in [regex]::Matches($Text, '[A-Za-z0-9+/]{40,}={0,2}')) {
            $value = $blob.Value
            $looksBase64 = $value -match '[+/=]' -or ($value -cmatch '[A-Z]' -and $value -cmatch '[a-z]')
            if ($looksBase64) {
                return "this carries an encoded blob beside a git or gh command; $openUp"
            }
        }
    }
}

function Get-HookCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Json
    )

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return
    }

    # System.Text.Json, not ConvertFrom-Json: loading that cmdlet's module adds ~170 ms to every tool call.
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        $root = $document.RootElement
        $tool = [System.Text.Json.JsonElement]::new()
        $toolInput = [System.Text.Json.JsonElement]::new()
        $command = [System.Text.Json.JsonElement]::new()
        if ($root.ValueKind -ne 'Object' -or -not $root.TryGetProperty('tool_name', [ref]$tool)) {
            return
        }

        if ($tool.ValueKind -ne 'String' -or $tool.GetString() -cnotin 'Bash', 'PowerShell') {
            return
        }

        if (-not $root.TryGetProperty('tool_input', [ref]$toolInput) -or $toolInput.ValueKind -ne 'Object') {
            return
        }

        if (-not $toolInput.TryGetProperty('command', [ref]$command) -or $command.ValueKind -ne 'String') {
            return
        }

        return $command.GetString()
    }
    finally {
        $document.Dispose()
    }
}

try {
    $command = Get-HookCommand -Json ([Console]::In.ReadToEnd())
    if ($null -eq $command) {
        exit 0
    }

    # Join shell line continuations so a flag split across lines is still seen.
    $joined = $command -replace '[\x5c\x60]\r?\n', ''

    # The override is read only from the hook's own environment, never from the command, so the
    # model cannot grant it to itself.
    $override = $env:AI_HARNESS_ALLOW_HISTORY_REWRITE -match '^(?i)(?:1|true)$'
    if ($override -and [regex]::IsMatch($joined, '(?i)\b(?:push|send-pack|branch)\b')) {
        [Console]::Error.WriteLine('Block-DangerousGit: history-rewrite override is active for this session')
    }

    $reason = Get-DenyReason -Text $joined -Override:$override
    if (-not $reason) {
        exit 0
    }

    $reasonJson = [System.Text.Json.JsonSerializer]::Serialize("Blocked by ai-harness: $reason.", [string])
    $fields = @(
        '"hookEventName":"PreToolUse"'
        '"permissionDecision":"deny"'
        '"permissionDecisionReason":' + $reasonJson
    )
    [Console]::Out.WriteLine('{"hookSpecificOutput":{' + ($fields -join ',') + '}}')
    exit 0
}
catch {
    # Fail closed: block the call rather than let an unchecked command through.
    $message = "Block-DangerousGit blocked the command (it could not be checked): $($_.Exception.Message)"
    [Console]::Error.WriteLine($message)
    exit 2
}

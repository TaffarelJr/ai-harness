#Requires -Version 7.4

<#
.SYNOPSIS
    Asks before a shell command that force-pushes or deletes the default
    branch, merges a pull request, or hides what it runs.
.DESCRIPTION
    A Claude Code PreToolUse hook for the Bash and PowerShell tools. It reads
    the hook input from standard input and scans tool_input.command as text.
    It never blocks a command: one it flags gets an "ask" decision, so the
    permission prompt shows the reason and a person approves or declines it.
    Anything else is left to the normal permission flow.

    Each rule is judged within one command segment, the text between `;`,
    `&&`, `||`, `|`, `&` and line breaks, so a word in a string or in a
    neighboring command does not count. A force-push or a branch delete to a
    named feature branch passes; one aimed at the default branch (main or
    master), or at no named branch, asks. Setting the environment variable
    AI_HARNESS_ALLOW_HISTORY_REWRITE to 1 or true in the hook's own
    environment lets those pass for any branch for that session; merging a
    pull request still asks. It never reaches the network. A command it
    cannot check asks too, and the prompt says why.
.INPUTS
    System.String. The hook input JSON, on standard input.
.OUTPUTS
    None, or the ask decision as JSON on standard output.
.EXAMPLE
    $hookInput = '{"tool_name":"Bash","tool_input":{"command":"git push -f"}}'
    $hookInput | pwsh -NoProfile -File ./Block-DangerousGit.ps1

    Prints an ask decision, because the force-push names no branch.
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
        Returns the branches a push segment names, and whether any is the default.
    .DESCRIPTION
        Reads the destination of each refspec after push or send-pack: the
        part after a colon, else the refspec itself, with a leading + and a
        refs/heads/ prefix stripped. The first bare operand is the remote; the
        rest are refspecs. A bare HEAD or an empty destination counts as
        unnamed. A variable counts as named, because its value is unknown here.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Token
    )

    $verb = -1
    for ($i = 0; $i -lt $Token.Count; $i++) {
        if ($Token[$i] -ceq 'push' -or $Token[$i] -ceq 'send-pack') {
            $verb = $i
            break
        }
    }

    $raw = [System.Collections.Generic.List[string]]::new()
    $bare = [System.Collections.Generic.List[string]]::new()
    for ($i = $verb + 1; $verb -ge 0 -and $i -lt $Token.Count; $i++) {
        $one = $Token[$i]
        if ($one.StartsWith('-')) {
            continue
        }

        if ($one.StartsWith('+') -or $one.Contains(':')) {
            $raw.Add((Get-DestinationBranch -Refspec $one))
        }
        else {
            $bare.Add($one)
        }
    }

    for ($i = 1; $i -lt $bare.Count; $i++) {
        $raw.Add((Get-DestinationBranch -Refspec $bare[$i]))
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

    return [PSCustomObject]@{
        Named      = $named
        HasDefault = $hasDefault
    }
}

function Get-SegmentReason {
    <#
    .SYNOPSIS
        Returns why one command segment needs a person's approval, or nothing.
    .DESCRIPTION
        The tool names git and gh are matched without case; git subcommands
        are matched with case, as git requires them.
    .PARAMETER Segment
        One command segment, with line continuations already joined.
    .PARAMETER Override
        Lets force-pushes and branch deletions to any branch pass.
    .OUTPUTS
        System.String. The reason, phrased to follow "this command", or
        nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Segment,

        [switch]$Override
    )

    $token = @($Segment -split '\s+' | ForEach-Object { $_.Trim('"', "'", '(', ')') } | Where-Object { $_ -ne '' })
    $git = [regex]::IsMatch($Segment, '(?i)\bgit(?:\.exe)?\b')
    $gh = [regex]::IsMatch($Segment, '(?i)\bgh(?:\.exe)?\b')

    if ($git -and -not $Override -and ($token -ccontains 'push' -or $token -ccontains 'send-pack')) {
        $force = Test-Any -Text $Segment -Pattern @(
            '--force',                      # --force, --force-with-lease[=val], --force-if-includes
            '(?:^|\s)-[a-z]*f[a-z]*\b',     # a short-flag cluster carrying f
            '(?:^|\s)\+[\w./:-]+'           # a +refspec force
        )
        $delete = Test-Any -Text $Segment -Pattern @(
            '--del[a-z]*',                  # --delete and every abbreviation down to --del
            '(?:^|\s)-[a-z]*d[a-z]*\b',     # a short-flag cluster carrying d
            '(?:^|\s):[\w./-]+'             # a :branch delete refspec
        )
        $bulk = (Test-Any -Text $Segment -Pattern @('--mirror', '--prune\w*')) -or
            ($force -and [regex]::IsMatch($Segment, '(?:^|\s)--all\b'))
        if ($bulk) {
            return 'pushes in bulk (--mirror, --prune or --force --all), which can rewrite many branches at once'
        }

        if ($force -or $delete) {
            $dest = Get-PushDestination -Token $token
            if ($dest.Named.Count -eq 0) {
                return 'force-pushes or deletes without naming a branch, so it may hit the default branch'
            }

            if ($dest.HasDefault) {
                return 'force-pushes or deletes the default branch (main or master)'
            }
        }
    }

    if ($git -and -not $Override -and $token -ccontains 'branch' -and
        [regex]::IsMatch($Segment, '\b(?:refs/heads/)?(?:main|master)\b')) {
        $destructive = [regex]::IsMatch($Segment, '(?:^|\s)-[A-Za-z]*[DM][A-Za-z]*\b')
        $forceDelete = (Test-Any -Text $Segment -Pattern @('--delete', '(?:^|\s)-[a-z]*d[a-z]*\b')) -and
            (Test-Any -Text $Segment -Pattern @('--force', '(?:^|\s)-[a-z]*f[a-z]*\b'))
        if ($destructive -or $forceDelete) {
            return 'force-deletes or force-renames the default branch (main or master)'
        }
    }

    if ($gh) {
        $flag = '(?:\s+-{1,2}[\w-]+(?:[= ][^\s-]\S*)?)*'
        if ([regex]::IsMatch($Segment, "(?i)\bgh(?:\.exe)?$flag\s+pr$flag\s+merge\b")) {
            return 'merges a pull request, which is a person''s decision'
        }

        if ([regex]::IsMatch($Segment, '(?i)\bapi\b')) {
            $mutating = [regex]::IsMatch($Segment, '(?i)(?:-X|--method)\s*=?\s*["'']?(?:DELETE|PATCH|PUT|POST)\b')
            if ($mutating -and (Test-Any -Text $Segment -Pattern @('git/refs', 'pulls/\S+/merge'))) {
                return 'calls the GitHub API to change a ref or merge a pull request'
            }

            if ([regex]::IsMatch($Segment, '\bgraphql\b')) {
                if (Test-Any -Text $Segment -Pattern @('mergePullRequest', 'deleteRef', 'updateRefs?\b')) {
                    return 'sends a GraphQL mutation that merges a pull request or changes a ref'
                }

                if (Test-Any -Text $Segment -Pattern @('=@', '(?i)(?:-F|--field|-f|--raw-field)\s+\S*@')) {
                    return 'sends a GraphQL query read from a file, so what it does cannot be seen here'
                }
            }
        }

        if ([regex]::IsMatch($Segment, '(?i)\bgh(?:\.exe)?\s+alias\s+set\b')) {
            return 'defines a gh alias, which can hide the command it runs'
        }
    }

    if ($git -and (Test-Any -Text $Segment -Pattern @('(?i)\s-c\s*["'']?alias\.', 'alias\.[\w-]+\s*='))) {
        return 'defines a git alias inline, which can hide the command it runs'
    }

    if ([regex]::IsMatch($Segment, 'GIT_CONFIG_(?:COUNT|KEY_\d+|VALUE_\d+|PARAMETERS)\s*=')) {
        return 'injects git configuration through GIT_CONFIG_* variables, which can change what git does'
    }

    if ([regex]::IsMatch($Segment, '(?i)(?:^|\s)eval\s')) {
        return 'uses eval, so what runs is built at run time and cannot be seen here'
    }

    if ([regex]::IsMatch($Segment, '(?i)\bxargs\b.*\bgit\b')) {
        return 'pipes into xargs git, so the arguments git receives cannot be seen here'
    }

    if ([regex]::IsMatch($Segment, '(?i)\b(?:invoke-expression|iex)\b')) {
        return 'uses Invoke-Expression, so what runs is built at run time and cannot be seen here'
    }

    if ([regex]::IsMatch($Segment, '(?i)\b(?:start-process|saps)\b.{0,40}?\bgit\b')) {
        return 'starts git through Start-Process, which hides its arguments'
    }

    # -EncodedCommand and every prefix PowerShell accepts for it; -ExecutionPolicy does not match.
    if ([regex]::IsMatch($Segment, '(?i)\b(?:pwsh|powershell)(?:\.exe)?\b.*?\s-e(?:c|n[a-z]*)?\b')) {
        return 'runs an encoded PowerShell command, which hides the script'
    }
}

function Get-AskReason {
    <#
    .SYNOPSIS
        Returns why a command needs a person's approval, or nothing.
    .PARAMETER Text
        The command, with line continuations already joined.
    .PARAMETER Override
        Lets force-pushes and branch deletions to any branch pass.
    .OUTPUTS
        System.String. The reason, phrased to follow "this command", or
        nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Override
    )

    # The only rule that spans a pipe: decoding base64 straight into a shell.
    if ([regex]::IsMatch($Text, '(?i)\bbase64\s+(?:-d|-D|--decode)\b[^\r\n;]*\|\s*(?:sudo\s+)?(?:ba|z|da)?sh\b')) {
        return 'decodes base64 into a shell, which hides the script'
    }

    foreach ($segment in [regex]::Split($Text, '&&|\|\||[;&|\r\n]')) {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            continue
        }

        $reason = Get-SegmentReason -Segment $segment -Override:$Override
        if ($reason) {
            return $reason
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

function Write-AskDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Reason
    )

    $reasonJson = [System.Text.Json.JsonSerializer]::Serialize("ai-harness: this command $Reason.", [string])
    $fields = @(
        '"hookEventName":"PreToolUse"'
        '"permissionDecision":"ask"'
        '"permissionDecisionReason":' + $reasonJson
    )
    [Console]::Out.WriteLine('{"hookSpecificOutput":{' + ($fields -join ',') + '}}')
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

    $reason = Get-AskReason -Text $joined -Override:$override
    if ($reason) {
        Write-AskDecision -Reason $reason
    }

    exit 0
}
catch {
    # Neither block nor wave through a command that could not be checked: ask.
    Write-AskDecision -Reason "could not be checked by the hook ($($_.Exception.Message)); read it before approving"
    exit 0
}

#Requires -Version 7.4

<#
.SYNOPSIS
    Brings the harness current: pulls the checkout, reinstalls, updates the
    plugins, and reports drift in the generated settings.
.DESCRIPTION
    Pulls with --ff-only, so local commits or a diverged branch stop the pull
    rather than merge. It then checks harness.json, local/harness.json and
    claude/plugins.json as the install does, and stops before installing
    anything if one of them fails. Before reinstalling it compares every
    generated settings file with the sidecar the last install wrote, so the
    drift report shows what Claude Code or a person changed since: typically
    permissions Claude Code saved. The reinstall backs such a file up before
    replacing it. Exits 1 if any step failed.
.PARAMETER HomePath
    The home directory to install into. Defaults to $HOME.
.PARAMETER PersonalRoot
    The folder that holds the personal repositories. Passed to the install.
.PARAMETER WorkRoot
    The folder that holds the work repositories. Passed to the install.
.PARAMETER LocalPath
    The folder that holds this machine's fragments. Defaults to local/ in
    the checkout.
.PARAMETER SkipModules
    Leaves out installing and updating PowerShell modules.
.PARAMETER SkipPlugins
    Leaves out installing and updating plugins.
.PARAMETER SkipMcp
    Leaves out the MCP servers.
.PARAMETER NonInteractive
    Never prompts. Passed to the install.
.PARAMETER SkipPull
    Reinstalls from the checkout as it is, without pulling.
.PARAMETER WhatIf
    Shows what would happen if the command runs. The command is not run.
.PARAMETER Confirm
    Prompts for confirmation before the command runs.
.INPUTS
    None.
.OUTPUTS
    None. Progress and the drift report are written to the host.
.EXAMPLE
    ./scripts/Update-Harness.ps1

    Pulls, reinstalls, updates the plugins and prints the drift report.
.EXAMPLE
    ./scripts/Update-Harness.ps1 -SkipPull -SkipPlugins -SkipMcp

    Reinstalls the local checkout and reports drift, touching nothing else.
.LINK
    https://github.com/TaffarelJr/ai-harness/blob/main/README.md
#>
[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'The progress lines and the report are for the person at the console, not data.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Most parameters reach Install-Harness.ps1 through $PSBoundParameters.')]
param(
    [string]$HomePath = $HOME,

    [string]$PersonalRoot,

    [string]$WorkRoot,

    [string]$LocalPath,

    [switch]$SkipModules,

    [switch]$SkipPlugins,

    [switch]$SkipMcp,

    [switch]$NonInteractive,

    [switch]$SkipPull
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force

$state = @{
    Failed = 0
}
$instructionDriftBefore = @()
$change = @{
    WhatIf  = [bool]$WhatIfPreference
    Confirm = $ConfirmPreference -eq 'Low'
}
$manifest = $null
$manifestsChecked = $false
$pluginData = $null
$driftBefore = @()
$pluginManifest = $null
$inventory = $null

function Invoke-UpdateStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [scriptblock]$Step
    )

    try {
        Invoke-HarnessStep -Activity $Activity -ScriptBlock $Step
    }
    catch {
        $state.Failed++
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-MissingRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    if ($Target.Contains('{personalRoot}') -and -not $personalPath) {
        return 'no personal root is known'
    }

    if ($Target.Contains('{workRoot}') -and -not $workPath) {
        return 'no work root is known'
    }
}

function Get-SettingDrift {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Setting
    )

    $record = [PSCustomObject]@{
        Target     = $Setting.Target
        Status     = 'NoRoot'
        Reason     = Get-MissingRoot -Target $Setting.Target
        Difference = @()
    }
    if ($record.Reason) {
        return $record
    }

    try {
        $target = Resolve-HarnessPath -Path $Setting.Target @resolve
        $drift = Get-HarnessSettingDrift -Target $target
        $record.Status = $drift.Status
        $record.Reason = $drift.Reason
        $record.Difference = $drift.Difference
    }
    catch {
        $record.Status = 'Unreadable'
        $record.Reason = $_.Exception.Message
    }

    return $record
}

function Format-DriftLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Difference
    )

    $symbol = switch ($Difference.Change) {
        'Added' { '+' }
        'Removed' { '-' }
        default { '~' }
    }

    # Only values added under permissions are shown: elsewhere a value may be a secret or come from local/.
    $value = ''
    $isPermission = $Difference.Path -match '^permissions(\.|\[|$)'
    $strings = @($Difference.Value | Where-Object { $_ -is [string] })
    if ($Difference.Change -eq 'Added' -and $isPermission -and $strings.Count -gt 0) {
        $value = ": $($strings -join ', ')"
    }

    return "    $symbol $($Difference.Path)$value"
}

try {
    $root = Get-HarnessRoot
    $homeFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HomePath)
    if (-not [IO.Directory]::Exists($homeFull)) {
        throw "The home path $homeFull does not exist."
    }

    $localFull = if ($LocalPath) {
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LocalPath)
    }
    else {
        Join-Path $root 'local'
    }

    $personalPath = Resolve-HarnessContextRoot -Path $PersonalRoot
    $workPath = Resolve-HarnessContextRoot -Path $WorkRoot
}
catch {
    Write-Host "Update-Harness failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$note = if ($change.WhatIf) { ' (WhatIf: nothing is changed)' } else { '' }
Write-Host "Updating ai-harness in $root for $homeFull$note"

Invoke-UpdateStep -Activity "Pulling $root" -Step {
    if ($SkipPull) {
        return 'skipped (-SkipPull)'
    }

    $git = @{
        Command          = 'git'
        Environment      = @{
            GIT_TERMINAL_PROMPT = '0'
            GIT_EDITOR          = 'true'
        }
        WorkingDirectory = $root
    }
    $read = @{
        ArgumentList = @('-C', $root, 'rev-parse', '--short', 'HEAD')
        WhatIf       = $false
        Confirm      = $false
    }
    $before = (Invoke-HarnessNative @git @read).Output | Select-Object -First 1
    $pulled = Invoke-HarnessNative @git @change -ArgumentList @('-C', $root, 'pull', '--ff-only') -TimeoutSeconds 300
    if ($null -eq $pulled) {
        return "would pull (at $before now)"
    }

    $after = (Invoke-HarnessNative @git @read).Output | Select-Object -First 1
    if ($before -ceq $after) {
        return "up to date at $before"
    }

    return "updated $before -> $after"
}

Invoke-UpdateStep -Activity 'Checking the manifests' -Step {
    $script:manifest = Read-HarnessManifest -Root $root
    $localConfig = Read-HarnessLocalConfig -LocalPath $localFull
    $checked = @('harness.json')
    if ([IO.File]::Exists($localConfig.Path)) {
        $checked += 'local/harness.json'
    }

    if (-not $personalPath) {
        $script:personalPath = $localConfig.PersonalRoot
    }

    if (-not $workPath) {
        $script:workPath = $localConfig.WorkRoot
    }

    if ($manifest.Plugins) {
        $path = Resolve-HarnessPath -Path $manifest.Plugins -Root $root -HomePath $homeFull -LocalPath $localFull
        if ([IO.File]::Exists($path)) {
            $script:pluginData = Read-HarnessPluginManifest -Path $path
            $checked += $manifest.Plugins
        }
    }

    $script:manifestsChecked = $true
    return "checked $($checked -join ', ')"
}

if (-not $manifestsChecked) {
    $stopped = 'stopped before the install. Fix the manifest and run again.'
    Write-Host "Update-Harness${note}: $stopped" -ForegroundColor Red
    exit 1
}

if ($personalPath -and -not [IO.Directory]::Exists($personalPath)) {
    Write-Warning "The personal root $personalPath does not exist, so {personalRoot} targets are not checked."
    $personalPath = $null
}

if ($workPath -and -not [IO.Directory]::Exists($workPath)) {
    Write-Warning "The work root $workPath does not exist, so {workRoot} targets are not checked."
    $workPath = $null
}

$resolve = @{
    Root         = $root
    HomePath     = $homeFull
    LocalPath    = $localFull
    PersonalRoot = $personalPath
    WorkRoot     = $workPath
}

Invoke-UpdateStep -Activity 'Reading the generated files before the install' -Step {
    $script:driftBefore = @(foreach ($setting in $manifest.Settings) { Get-SettingDrift -Setting $setting })
    $script:instructionDriftBefore = @(
        foreach ($instruction in $manifest.Instructions) {
            foreach ($targetSpec in $instruction.Targets) {
                if (Get-MissingRoot -Target $targetSpec) {
                    continue
                }

                $target = Resolve-HarnessPath -Path $targetSpec @resolve
                $instructionState = Get-HarnessGeneratedState -Path $target
                $edited = $instructionState.Generated -and $instructionState.HashKnown -and
                    -not $instructionState.HashMatches
                if ($edited) {
                    $targetSpec
                }
            }
        }
    )
    $changed = @($driftBefore | Where-Object { $_.Status -ceq 'Drift' }).Count
    $edited = $instructionDriftBefore.Count
    return "$($driftBefore.Count) settings files ($changed with drift), $edited edited instruction files"
}

$installArguments = @{}
foreach ($entry in $PSBoundParameters.GetEnumerator()) {
    if ($entry.Key -cne 'SkipPull') {
        $installArguments[$entry.Key] = $entry.Value
    }
}

& (Join-Path $PSScriptRoot 'Install-Harness.ps1') @installArguments
if ($LASTEXITCODE -ne 0) {
    $state.Failed++
}

$platform = Get-HarnessPlatform
foreach ($module in $manifest.Modules) {
    Invoke-UpdateStep -Activity "Updating PowerShell module $($module.Name)" -Step {
        if ($SkipModules) {
            return 'skipped (-SkipModules)'
        }

        if ($module.Platform -and $module.Platform -cne $platform) {
            return "skipped (only on $($module.Platform))"
        }

        if (-not (Get-Module -ListAvailable -Name $module.Name)) {
            Write-Warning "$($module.Name) is not installed, so it is not updated."
            return 'skipped'
        }

        if ($change.WhatIf) {
            return 'would update from the PowerShell Gallery'
        }

        try {
            Update-Module -Name $module.Name -ErrorAction Stop
        }
        catch {
            throw "Updating the PowerShell module $($module.Name) failed; the PowerShell Gallery may be " +
                "unreachable (a proxy can block it): $($_.Exception.Message)"
        }

        return 'updated from the PowerShell Gallery'
    }
}

Invoke-UpdateStep -Activity 'Reading the installed plugins' -Step {
    if ($SkipPlugins) {
        return 'skipped (-SkipPlugins)'
    }

    if (-not $manifest.Plugins) {
        Write-Warning 'harness.json names no plugin manifest.'
        return 'skipped'
    }

    if ($null -eq $pluginData) {
        Write-Warning "$($manifest.Plugins) does not exist yet, so no plugins are updated."
        return 'skipped'
    }

    if (-not (Test-HarnessCommand -Name 'claude')) {
        Write-Warning 'claude is not on PATH, so no plugins are updated.'
        return 'skipped'
    }

    $script:pluginManifest = $pluginData
    if ($change.WhatIf) {
        # Reading the inventory runs the CLI, which writes .claude.json; skip it under -WhatIf.
        $script:inventory = [PSCustomObject]@{
            Environment      = Get-HarnessClaudeEnvironment -HomePath $homeFull
            WorkingDirectory = $homeFull
            Plugins          = @()
        }
        return "$($pluginManifest.Plugins.Count) plugins (would read the installed set under -WhatIf)"
    }

    $script:inventory = Get-HarnessClaudeInventory -HomePath $homeFull
    return "$($pluginManifest.Plugins.Count) plugins"
}

if ($null -ne $pluginManifest -and $null -ne $inventory) {
    foreach ($plugin in $pluginManifest.Plugins) {
        Invoke-UpdateStep -Activity "Updating plugin $($plugin.Id)" -Step {
            if ($change.WhatIf) {
                return "would update (if installed at $($plugin.Scope) scope)"
            }

            $installed = @($inventory.Plugins |
                    Where-Object { $_.Id -ceq $plugin.Id -and $_.Scope -ceq $plugin.Scope })
            if ($installed.Count -eq 0) {
                Write-Warning "$($plugin.Id) is not installed at $($plugin.Scope) scope, so it is not updated."
                return 'skipped'
            }

            $run = @{
                Command          = 'claude'
                ArgumentList     = @('plugin', 'update', $plugin.Id, '--scope', $plugin.Scope, '--json')
                Environment      = $inventory.Environment
                WorkingDirectory = $inventory.WorkingDirectory
                TimeoutSeconds   = 600
            }
            $result = Invoke-HarnessNative @change @run
            if ($null -eq $result) {
                return 'skipped (confirmation declined)'
            }

            try {
                $reply = ($result.Output | Select-Object -Last 1) | ConvertFrom-Json -AsHashtable
                if ($reply -is [System.Collections.IDictionary] -and $reply['message'] -is [string]) {
                    return $reply['message']
                }
            }
            catch {
                Write-Verbose "The update result was not JSON: $($_.Exception.Message)"
            }

            return 'updated'
        }
    }
}

Write-Host 'Drift report: what changed in each generated settings file since the install before this one'
foreach ($record in $driftBefore) {
    $backedUp = if ($change.WhatIf) { 'the install would back it up' } else { 'the install backed it up' }
    switch ($record.Status) {
        'NoRoot' {
            Write-Host "  $($record.Target): not checked, because $($record.Reason)" -ForegroundColor DarkGray
            break
        }
        'Missing' {
            Write-Host "  $($record.Target): did not exist before this run" -ForegroundColor DarkGray
            break
        }
        'NoSidecar' {
            Write-Host "  $($record.Target): the harness did not write it, so $backedUp" -ForegroundColor Yellow
            break
        }
        'Unreadable' {
            $line = "  $($record.Target): it could not be read ($($record.Reason)), so $backedUp"
            Write-Host $line -ForegroundColor Yellow
            break
        }
        'Clean' {
            Write-Host "  $($record.Target): no drift" -ForegroundColor DarkGray
            break
        }
        default {
            Write-Host "  $($record.Target): $($record.Difference.Count) changes; $backedUp" -ForegroundColor Yellow
            foreach ($difference in $record.Difference) {
                Write-Host (Format-DriftLine -Difference $difference) -ForegroundColor Yellow
            }

            $promote = 'Promote what should stay into claude/settings.json,'
            $promote += ' or local/settings.json if it is machine-specific; the reinstall drops the rest.'
            Write-Host "    $promote"
        }
    }
}

foreach ($target in $instructionDriftBefore) {
    $fate = if ($change.WhatIf) { 'the install would back it up' } else { 'the install backed it up' }
    Write-Host "  ${target}: edited below the generated header, so $fate" -ForegroundColor Yellow
    Write-Host '    Move the change into its source under claude/ or contexts/; the reinstall regenerates it.'
}

$color = if ($state.Failed -gt 0) { 'Red' } else { 'Green' }
Write-Host "Update-Harness${note}: $($state.Failed) failed steps" -ForegroundColor $color
exit ([int]($state.Failed -gt 0))

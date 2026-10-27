#Requires -Version 7.4

<#
.SYNOPSIS
    Installs the harness into a home directory.
.DESCRIPTION
    First checks harness.json, local/harness.json and claude/plugins.json,
    and stops before changing anything if one of them has a missing field,
    a wrong type or a key it does not know. Then, in order: settles the
    personal and work roots, links the folders the tools only read,
    generates the instruction files and the settings, installs the listed
    PowerShell modules, then adds the listed plugins and MCP servers through
    the Claude Code CLI. Anything it replaces is renamed beside itself with
    a .harness-backup-<timestamp> suffix, never deleted. Each step prints
    one progress line; the run ends with a summary and exits 1 if any step
    failed. A source that does not exist yet is skipped with a warning.
.PARAMETER HomePath
    The home directory to install into. Defaults to $HOME. For any other
    folder the Claude Code CLI is pointed at <folder>/.claude as well.
.PARAMETER PersonalRoot
    The folder that holds the personal repositories, for {personalRoot}
    targets. Saved in local/harness.json for later runs.
.PARAMETER WorkRoot
    The folder that holds the work repositories, for {workRoot} targets.
    Saved in local/harness.json for later runs. Never asked for: a machine
    without one skips the {workRoot} targets.
.PARAMETER LocalPath
    The folder that holds this machine's fragments. Defaults to local/ in
    the checkout.
.PARAMETER SkipModules
    Leaves out the PowerShell modules in harness.json.
.PARAMETER SkipPlugins
    Leaves out the marketplaces and plugins in claude/plugins.json.
.PARAMETER SkipMcp
    Leaves out the MCP servers in claude/mcp.json and local/mcp.json.
.PARAMETER NonInteractive
    Never prompts. An unknown personal root is then skipped with a warning.
.PARAMETER WhatIf
    Shows what would happen if the command runs. The command is not run.
.PARAMETER Confirm
    Prompts for confirmation before the command runs.
.INPUTS
    None.
.OUTPUTS
    None. Progress is written to the host.
.EXAMPLE
    ./scripts/Install-Harness.ps1 -WhatIf

    Shows every link and file the install would create, without creating any.
.EXAMPLE
    ./scripts/Install-Harness.ps1 -PersonalRoot ~/source/personal -SkipMcp

    Installs everything except the MCP servers, and remembers the personal
    root.
.EXAMPLE
    ./scripts/Install-Harness.ps1 -WorkRoot ~/source/work

    Also generates the {workRoot} targets, and remembers the work root.
.LINK
    https://github.com/TaffarelJr/ai-harness/blob/main/README.md
#>
[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'The progress lines are for the person at the console, not data.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'SkipModules',
    Justification = 'Read inside a step script block, which the rule does not follow.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'SkipPlugins',
    Justification = 'Read inside a step script block, which the rule does not follow.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'SkipMcp',
    Justification = 'Read inside a step script block, which the rule does not follow.')]
param(
    [string]$HomePath = $HOME,

    [string]$PersonalRoot,

    [string]$WorkRoot,

    [string]$LocalPath,

    [switch]$SkipModules,

    [switch]$SkipPlugins,

    [switch]$SkipMcp,

    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force

$summary = [ordered]@{
    Linked    = 0
    Generated = 0
    Installed = 0
    Unchanged = 0
    BackedUp  = 0
    Skipped   = 0
    Failed    = 0
}
$change = @{
    WhatIf  = [bool]$WhatIfPreference
    Confirm = $ConfirmPreference -eq 'Low'
}
$manifest = $null
$localConfig = $null
$manifestsChecked = $false
$pluginData = $null
$inventory = $null
$pluginManifest = $null
$mcpServers = @()

function Invoke-InstallStep {
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
        $summary.Failed++
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Read-PersonalRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $answer = Read-Host 'Folder that holds your personal repositories (blank to skip)'
    }
    catch {
        Write-Warning "Cannot ask for the personal root here: $($_.Exception.Message)"
        return
    }

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return
    }

    $path = Resolve-HarnessContextRoot -Path $answer.Trim().Trim('"')
    if (-not [IO.Directory]::Exists($path)) {
        Write-Warning "$path does not exist, so it is not saved."
        return
    }

    return $path
}

function Get-MissingRootOutcome {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    if ($Target.Contains('{personalRoot}') -and -not $personalPath) {
        Write-Warning "No personal root is known, so $Target is skipped. Pass -PersonalRoot to set one."
        $summary.Skipped++
        return 'skipped'
    }

    if ($Target.Contains('{workRoot}') -and -not $workPath) {
        $summary.Skipped++
        return $workSkip
    }
}

function Initialize-Inventory {
    [CmdletBinding()]
    param()

    if ($null -ne $script:inventory) {
        return
    }

    if ($change.WhatIf) {
        # Reading the inventory runs the CLI, which writes .claude.json into the config dir. Under -WhatIf
        # skip it and treat everything as not-yet-installed, so the apply steps only project.
        Invoke-InstallStep -Activity 'Reading what Claude Code has installed' -Step {
            'would read (skipped under -WhatIf)'
        }
        $script:inventory = [PSCustomObject]@{
            Environment      = Get-HarnessClaudeEnvironment -HomePath $homeFull
            WorkingDirectory = $homeFull
            Marketplaces     = @()
            Plugins          = @()
            McpServers       = @()
        }
        return
    }

    Invoke-InstallStep -Activity 'Reading what Claude Code has installed' -Step {
        $script:inventory = Get-HarnessClaudeInventory -HomePath $homeFull
        $counts = @(
            "$($inventory.Marketplaces.Count) marketplaces"
            "$($inventory.Plugins.Count) plugins"
            "$($inventory.McpServers.Count) MCP servers"
        )
        $text = $counts -join ', '
        if ($inventory.Environment.ContainsKey('CLAUDE_CONFIG_DIR')) {
            $text += ' (in this home''s .claude)'
        }

        return $text
    }
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

    $personalArg = Resolve-HarnessContextRoot -Path $PersonalRoot
    if ($personalArg -and -not [IO.Directory]::Exists($personalArg)) {
        throw "The personal root $personalArg does not exist."
    }

    $workArg = Resolve-HarnessContextRoot -Path $WorkRoot
    if ($workArg -and -not [IO.Directory]::Exists($workArg)) {
        throw "The work root $workArg does not exist."
    }

    $realHome = Test-HarnessSamePath -Left $homeFull -Right $HOME
}
catch {
    Write-Host "Install-Harness failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$note = if ($change.WhatIf) { ' (WhatIf: nothing is changed)' } else { '' }
Write-Host "Installing ai-harness from $root into $homeFull$note"

Invoke-InstallStep -Activity 'Checking the manifests' -Step {
    $script:manifest = Read-HarnessManifest -Root $root
    $script:localConfig = Read-HarnessLocalConfig -LocalPath $localFull
    $checked = @('harness.json')
    if ([IO.File]::Exists($localConfig.Path)) {
        $checked += 'local/harness.json'
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
    $stopped = 'failed 1; stopped before changing anything. Fix the manifest and run again.'
    Write-Host "Summary${note}: $stopped" -ForegroundColor Red
    exit 1
}

$personalPath = $personalArg
$personalToSave = $personalArg
$trialWithoutRoot = $false
if (-not $personalPath) {
    if (-not $realHome) {
        # A trial install into another home must not touch the real personal root (item: trial footgun).
        $trialWithoutRoot = $true
    }
    elseif ($localConfig.PersonalRoot) {
        $personalPath = $localConfig.PersonalRoot
    }
    elseif (-not $NonInteractive -and -not $change.WhatIf) {
        $personalPath = Read-PersonalRoot
        $personalToSave = $personalPath
    }
}

Invoke-InstallStep -Activity 'Settling the personal root' -Step {
    if ($trialWithoutRoot) {
        $warn = "Installing into a home other than $HOME without -PersonalRoot: {personalRoot} targets are"
        $warn += ' skipped so the real personal root is left alone.'
        Write-Warning $warn
        return 'skipped'
    }

    if (-not $realHome -and $personalToSave) {
        # local/ describes the real home; a trial install into another home must not rewrite it.
        return "using $personalPath for this run only; not saved, because this is not the real home"
    }

    $changed = $personalToSave -and -not ($localConfig.PersonalRoot -and
        (Test-HarnessSamePath -Left $personalToSave -Right $localConfig.PersonalRoot))
    if ($changed) {
        Save-HarnessLocalConfig @change -LocalPath $localFull -PersonalRoot $personalToSave.Replace('\', '/')
        if ($change.WhatIf) {
            return "would save it to $($localConfig.Path)"
        }

        return "saved to $($localConfig.Path)"
    }

    if (-not $personalPath) {
        Write-Warning 'No personal root is known, so {personalRoot} targets are skipped. Pass -PersonalRoot to set one.'
        return 'skipped'
    }

    if (-not [IO.Directory]::Exists($personalPath)) {
        Write-Warning "The personal root in $($localConfig.Path) does not exist, so {personalRoot} targets are skipped."
        $script:personalPath = $null
        return 'skipped'
    }

    return "read from $($localConfig.Path)"
}

$workPath = $workArg
$workSkip = 'skipped (no work root on this machine)'
Invoke-InstallStep -Activity 'Settling the work root' -Step {
    if (-not $realHome) {
        if ($workArg) {
            return "using $workArg for this run only; not saved, because this is not the real home"
        }

        # As for the personal root: a trial install must not write into the real work root.
        $script:workSkip = 'skipped (not the real home, and no -WorkRoot)'
        return $workSkip
    }

    if ($workArg) {
        if ($localConfig.WorkRoot -and (Test-HarnessSamePath -Left $workArg -Right $localConfig.WorkRoot)) {
            return "already saved in $($localConfig.Path)"
        }

        Save-HarnessLocalConfig @change -LocalPath $localFull -WorkRoot $workArg.Replace('\', '/')
        if ($change.WhatIf) {
            return "would save it to $($localConfig.Path)"
        }

        return "saved to $($localConfig.Path)"
    }

    if (-not $localConfig.WorkRoot) {
        return 'none on this machine, so {workRoot} targets are skipped'
    }

    if (-not [IO.Directory]::Exists($localConfig.WorkRoot)) {
        Write-Warning "The work root in $($localConfig.Path) does not exist, so {workRoot} targets are skipped."
        $script:workSkip = 'skipped (the saved work root does not exist)'
        return 'skipped'
    }

    $script:workPath = $localConfig.WorkRoot
    return "read from $($localConfig.Path)"
}

$resolve = @{
    Root         = $root
    HomePath     = $homeFull
    LocalPath    = $localFull
    PersonalRoot = $personalPath
    WorkRoot     = $workPath
}

foreach ($link in $manifest.Links) {
    Invoke-InstallStep -Activity "Linking $($link.Target)" -Step {
        $skip = Get-MissingRootOutcome -Target $link.Target
        if ($skip) {
            return $skip
        }

        $source = Resolve-HarnessPath -Path $link.Source @resolve
        if ((Get-HarnessItem -Path $source).Kind -eq 'Missing') {
            Write-Warning "$($link.Source) does not exist yet, so $($link.Target) is not linked."
            $summary.Skipped++
            return 'skipped'
        }

        $target = Resolve-HarnessPath -Path $link.Target @resolve
        $result = New-HarnessLink @change -Source $source -Target $target
        if ($null -ne $result -and $result.Action -eq 'AlreadyLinked') {
            $summary.Unchanged++
            return 'already linked'
        }

        if ($change.WhatIf) {
            $summary.Linked++
            return "would link to $($link.Source)"
        }

        if ($null -eq $result) {
            $summary.Skipped++
            return 'skipped (confirmation declined)'
        }

        $summary.Linked++
        if ($result.Backup) {
            $summary.BackedUp++
            return "linked; what was there is now $(Split-Path -Leaf $result.Backup)"
        }

        return 'linked'
    }
}

foreach ($instruction in $manifest.Instructions) {
    foreach ($targetSpec in $instruction.Targets) {
        Invoke-InstallStep -Activity "Generating $targetSpec" -Step {
            $skip = Get-MissingRootOutcome -Target $targetSpec
            if ($skip) {
                return $skip
            }

            $source = Resolve-HarnessPath -Path $instruction.Source @resolve
            if (-not [IO.File]::Exists($source)) {
                Write-Warning "$($instruction.Source) does not exist yet, so $targetSpec is not generated."
                $summary.Skipped++
                return 'skipped'
            }

            $build = @{
                Source     = $source
                SourceName = $instruction.Source
            }
            if ($instruction.Local) {
                $fragment = Resolve-HarnessPath -Path $instruction.Local @resolve
                if ([IO.File]::Exists($fragment)) {
                    $build.Local = $fragment
                    $build.LocalName = $instruction.Local
                }
            }

            $text = Build-HarnessInstruction @build
            $with = if ($build.ContainsKey('Local')) { ' with the local fragment' } else { '' }
            $target = Resolve-HarnessPath -Path $targetSpec @resolve
            $existing = Get-HarnessItem -Path $target
            if ($existing.Kind -eq 'Directory') {
                throw "$target is a folder, not a file."
            }

            $current = $null
            if ($existing.Kind -eq 'File') {
                $current = try { Read-HarnessText -Path $target } catch { $null }
                if ($current -ceq $text) {
                    $summary.Unchanged++
                    return 'unchanged'
                }
            }

            # Back up anything we cannot prove we wrote and left untouched: a hand-made file, a link,
            # a header with no hash (an older version wrote it), or a body edited below the header.
            $backupWhy = $null
            if ($existing.Kind -eq 'Link') {
                $backupWhy = 'it was a link'
            }
            elseif ($existing.Kind -eq 'File') {
                $state = Get-HarnessGeneratedState -Path $target
                if (-not $state.Generated) {
                    $backupWhy = 'it was made by hand'
                }
                elseif (-not $state.HashKnown) {
                    $backupWhy = 'an older harness wrote it, without a hash to check'
                }
                elseif (-not $state.HashMatches) {
                    $backupWhy = 'it was edited below the generated header'
                }
            }

            $backup = if ($backupWhy) { Backup-HarnessItem @change -Path $target }
            Write-HarnessFile @change -Path $target -Text $text
            $summary.Generated++
            if ($change.WhatIf) {
                $first = if ($backupWhy) { ", backing it up first because $backupWhy" } else { '' }
                return "would generate$with$first"
            }

            if ($backup) {
                $summary.BackedUp++
                return "generated$with; backed up because $backupWhy, to $(Split-Path -Leaf $backup)"
            }

            return "generated$with"
        }
    }
}

foreach ($setting in $manifest.Settings) {
    Invoke-InstallStep -Activity "Generating $($setting.Target)" -Step {
        $skip = Get-MissingRootOutcome -Target $setting.Target
        if ($skip) {
            return $skip
        }

        $source = Resolve-HarnessPath -Path $setting.Source @resolve
        if (-not [IO.File]::Exists($source)) {
            Write-Warning "$($setting.Source) does not exist yet, so $($setting.Target) is not generated."
            $summary.Skipped++
            return 'skipped'
        }

        $data = Read-HarnessJson -Path $source
        if ($data -isnot [System.Collections.IDictionary]) {
            throw "$($setting.Source) is not a JSON object."
        }

        $with = ''
        if ($setting.Local) {
            $fragment = Resolve-HarnessPath -Path $setting.Local @resolve
            if ([IO.File]::Exists($fragment)) {
                $overlay = Read-HarnessJson -Path $fragment -HideDetail
                if ($overlay -isnot [System.Collections.IDictionary]) {
                    throw "$($setting.Local) is not a JSON object."
                }

                $data = Merge-HarnessObject -Base $data -Overlay $overlay
                $with = ' with the local fragment'
            }
        }

        if ($setting.Plugins -and $null -ne $pluginData) {
            $pluginSettings = Get-HarnessPluginSetting -PluginManifest $pluginData
            foreach ($entry in $pluginSettings.GetEnumerator()) {
                $data[$entry.Key] = if ($data.Contains($entry.Key)) {
                    Merge-HarnessObject -Base $entry.Value -Overlay $data[$entry.Key]
                }
                else {
                    $entry.Value
                }
            }

            if ($pluginSettings.PSBase.Count -gt 0) {
                $with += if ($with) { ' and claude/plugins.json' } else { ' with claude/plugins.json' }
            }
        }

        $hooksFolder = Join-Path -Path $root -ChildPath 'claude' -AdditionalChildPath 'hooks'
        $token = @{
            hooks = $hooksFolder.Replace('\', '/')
            home  = $homeFull.Replace('\', '/')
        }
        $data = Expand-HarnessToken -InputObject $data -Token $token
        $newLine = Get-HarnessNewLine -Text (Read-HarnessText -Path $source)
        $text = ConvertTo-HarnessJson -InputObject $data -NewLine $newLine
        if ($text -match '\{\{\w+\}\}') {
            Write-Warning "$($Matches[0]) in $($setting.Source) is not a known token, so it is left as written."
        }

        if ($text.Contains($token.hooks) -and -not [IO.Directory]::Exists($hooksFolder)) {
            Write-Warning 'These settings call scripts in claude/hooks, which does not exist yet.'
        }

        $target = Resolve-HarnessPath -Path $setting.Target @resolve
        $sidecar = Get-HarnessSidecarPath -Path $target
        $existing = Get-HarnessItem -Path $target
        if ($existing.Kind -eq 'Directory') {
            throw "$target is a folder, not a file."
        }

        # The target and its sidecar are written one after the other. If the target already equals what
        # we would write, there is no drift even when the sidecar is missing or stale (a crash between the
        # two writes): repair the sidecar and stop.
        if ($existing.Kind -eq 'File') {
            $currentTarget = try { Read-HarnessText -Path $target } catch { $null }
            if ($currentTarget -ceq $text) {
                $currentSidecar = try { Read-HarnessText -Path $sidecar } catch { $null }
                if ($currentSidecar -cne $text) {
                    Write-HarnessFile @change -Path $sidecar -Text $text
                }

                $summary.Unchanged++
                return 'unchanged'
            }
        }

        $reason = $null
        if ($existing.Kind -eq 'Link') {
            $reason = 'it was a link'
        }
        elseif ($existing.Kind -eq 'File') {
            $drift = Get-HarnessSettingDrift -Target $target
            $reason = switch ($drift.Status) {
                'NoSidecar' { 'the harness did not write it' }
                'Unreadable' { "it could not be read ($($drift.Reason))" }
                'Drift' { 'it changed since the last install' }
                default { $null }
            }
        }

        $backup = if ($reason) { Backup-HarnessItem @change -Path $target }
        Write-HarnessFile @change -Path $target -Text $text
        Write-HarnessFile @change -Path $sidecar -Text $text
        $summary.Generated++
        if ($change.WhatIf) {
            $first = if ($reason) { ", backing it up first because $reason" } else { '' }
            return "would generate$with$first"
        }

        if ($backup) {
            $summary.BackedUp++
            return "generated$with; backed up because $reason, to $(Split-Path -Leaf $backup)"
        }

        return "generated$with"
    }
}

$platform = Get-HarnessPlatform
foreach ($module in $manifest.Modules) {
    Invoke-InstallStep -Activity "Installing PowerShell module $($module.Name)" -Step {
        if ($SkipModules) {
            Write-Warning "PowerShell modules are skipped (-SkipModules)."
            $summary.Skipped++
            return 'skipped'
        }

        if ($module.Platform -and $module.Platform -cne $platform) {
            $summary.Skipped++
            return "skipped (only on $($module.Platform))"
        }

        if (Get-Module -ListAvailable -Name $module.Name) {
            $summary.Unchanged++
            return 'already installed'
        }

        if ($change.WhatIf) {
            $summary.Installed++
            return 'would install from the PowerShell Gallery'
        }

        try {
            # Install-Module fails non-terminating by default; -ErrorAction Stop makes the failure catchable.
            Install-Module -Name $module.Name -Scope CurrentUser -Force -ErrorAction Stop
        }
        catch {
            throw "Installing the PowerShell module $($module.Name) failed; the PowerShell Gallery may be " +
                "unreachable (a proxy can block it): $($_.Exception.Message)"
        }

        $summary.Installed++
        return 'installed from the PowerShell Gallery'
    }
}

$claudeFound = Test-HarnessCommand -Name 'claude'

Invoke-InstallStep -Activity 'Listing the plugins' -Step {
    if ($SkipPlugins) {
        Write-Warning 'Plugins are skipped (-SkipPlugins).'
        $summary.Skipped++
        return 'skipped'
    }

    if (-not $manifest.Plugins) {
        Write-Warning 'harness.json names no plugin manifest.'
        $summary.Skipped++
        return 'skipped'
    }

    if ($null -eq $pluginData) {
        Write-Warning "$($manifest.Plugins) does not exist yet, so no plugins are installed."
        $summary.Skipped++
        return 'skipped'
    }

    if (-not $claudeFound) {
        Write-Warning 'claude is not on PATH, so no plugins are installed.'
        $summary.Skipped++
        return 'skipped'
    }

    $script:pluginManifest = $pluginData
    return "$($pluginManifest.Marketplaces.Count) marketplaces, $($pluginManifest.Plugins.Count) plugins"
}

if ($null -ne $pluginManifest) {
    Initialize-Inventory
}

if ($null -ne $pluginManifest -and $null -ne $inventory) {
    $official = 'claude-plugins-official'
    $marketplaces = @($pluginManifest.Marketplaces)
    $usesOfficial = @($pluginManifest.Plugins | Where-Object { $_.Marketplace -ceq $official }).Count -gt 0
    if ($usesOfficial -and @($marketplaces | Where-Object { $_.Name -ceq $official }).Count -eq 0) {
        # Claude Code registers the official marketplace only in an interactive session; a script must add it.
        $marketplaces += [PSCustomObject]@{
            Name   = $official
            Source = 'anthropics/claude-plugins-official'
            Ref    = $null
        }
    }

    $listedMarketplaces = @($marketplaces | ForEach-Object { $_.Name })
    foreach ($marketplace in $marketplaces) {
        Invoke-InstallStep -Activity "Adding marketplace $($marketplace.Name)" -Step {
            if ($inventory.Marketplaces -ccontains $marketplace.Name) {
                $summary.Unchanged++
                return 'already added'
            }

            $source = $marketplace.Source
            if ($marketplace.Ref) {
                $source += "#$($marketplace.Ref)"
            }

            $run = @{
                Command          = 'claude'
                ArgumentList     = @('plugin', 'marketplace', 'add', $source, '--scope', 'user')
                Environment      = $inventory.Environment
                WorkingDirectory = $inventory.WorkingDirectory
                TimeoutSeconds   = 600
            }
            $result = Invoke-HarnessNative @change @run
            if ($change.WhatIf) {
                $summary.Installed++
                return "would add $source (unless already added)"
            }

            if ($null -eq $result) {
                $summary.Skipped++
                return 'skipped (confirmation declined)'
            }

            $summary.Installed++
            return "added $source"
        }
    }

    foreach ($plugin in $pluginManifest.Plugins) {
        Invoke-InstallStep -Activity "Installing plugin $($plugin.Id)" -Step {
            $installed = @($inventory.Plugins | Where-Object { $_.Id -ceq $plugin.Id -and $_.Scope -ceq $plugin.Scope })
            if ($installed.Count -gt 0) {
                $summary.Unchanged++
                return 'already installed'
            }

            $added = $inventory.Marketplaces -ccontains $plugin.Marketplace
            if (-not $added -and $listedMarketplaces -cnotcontains $plugin.Marketplace) {
                Write-Warning "The marketplace $($plugin.Marketplace) is neither added nor in claude/plugins.json."
                $summary.Skipped++
                return 'skipped'
            }

            $run = @{
                Command          = 'claude'
                ArgumentList     = @('plugin', 'install', $plugin.Id, '--scope', $plugin.Scope)
                Environment      = $inventory.Environment
                WorkingDirectory = $inventory.WorkingDirectory
                TimeoutSeconds   = 600
            }
            $result = Invoke-HarnessNative @change @run
            if ($change.WhatIf) {
                $summary.Installed++
                return "would install at $($plugin.Scope) scope (unless already installed)"
            }

            if ($null -eq $result) {
                $summary.Skipped++
                return 'skipped (confirmation declined)'
            }

            $summary.Installed++
            return "installed at $($plugin.Scope) scope"
        }
    }
}

Invoke-InstallStep -Activity 'Reading the MCP manifest' -Step {
    if ($SkipMcp) {
        Write-Warning 'MCP servers are skipped (-SkipMcp).'
        $summary.Skipped++
        return 'skipped'
    }

    $path = if ($manifest.Mcp) { Resolve-HarnessPath -Path $manifest.Mcp @resolve }
    $localMcp = Join-Path $localFull 'mcp.json'
    $hasShared = $path -and [IO.File]::Exists($path)
    $hasLocal = [IO.File]::Exists($localMcp)
    if (-not $hasShared -and -not $hasLocal) {
        $named = 'harness.json names no MCP manifest'
        if ($manifest.Mcp) {
            $named = "$($manifest.Mcp) does not exist yet"
        }

        Write-Warning "$named and there is no local/mcp.json, so no MCP servers are registered."
        $summary.Skipped++
        return 'skipped'
    }

    if (-not $claudeFound) {
        Write-Warning 'claude is not on PATH, so no MCP servers are registered.'
        $summary.Skipped++
        return 'skipped'
    }

    # One list keyed by name: a local server replaces a shared one of the same name, in its place.
    $servers = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    if ($hasShared) {
        foreach ($server in Read-HarnessMcpManifest -Path $path) {
            $servers[$server.Name] = $server
        }
    }

    $fromLocal = 0
    if ($hasLocal) {
        foreach ($server in Read-HarnessMcpManifest -Path $localMcp -HideDetail) {
            $servers[$server.Name] = $server
            $fromLocal++
        }
    }

    $script:mcpServers = @($servers.PSBase.Values)
    return "$($mcpServers.Count) servers ($fromLocal from local)"
}

if ($mcpServers.Count -gt 0) {
    Initialize-Inventory
}

if ($mcpServers.Count -gt 0 -and $null -ne $inventory) {
    foreach ($server in $mcpServers) {
        Invoke-InstallStep -Activity "Registering MCP server $($server.Name)" -Step {
            if ($inventory.McpServers -ccontains $server.Name) {
                $summary.Unchanged++
                return 'already registered'
            }

            $run = @{
                Command          = 'claude'
                ArgumentList     = @('mcp', 'add-json', '--scope', 'user', $server.Name, $server.Json)
                Environment      = $inventory.Environment
                WorkingDirectory = $inventory.WorkingDirectory
                Display          = "claude mcp add-json --scope user $($server.Name) <configuration hidden>"
                HideOutput       = $true
            }
            $result = Invoke-HarnessNative @change @run
            if ($change.WhatIf) {
                $summary.Installed++
                return 'would register at user scope (unless already registered)'
            }

            if ($null -eq $result) {
                $summary.Skipped++
                return 'skipped (confirmation declined)'
            }

            $summary.Installed++
            return 'registered at user scope'
        }
    }
}

$counts = @(
    "linked $($summary.Linked)"
    "generated $($summary.Generated)"
    "installed $($summary.Installed)"
    "unchanged $($summary.Unchanged)"
    "backed up $($summary.BackedUp)"
    "skipped $($summary.Skipped)"
    "failed $($summary.Failed)"
)
$color = if ($summary.Failed -gt 0) { 'Red' } else { 'Green' }
Write-Host "Summary${note}: $($counts -join ', ')" -ForegroundColor $color
exit ([int]($summary.Failed -gt 0))

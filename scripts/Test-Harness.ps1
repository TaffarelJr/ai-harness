#Requires -Version 7.4

<#
.SYNOPSIS
    Checks the checkout and, optionally, an installation of it.
.DESCRIPTION
    Without -Installed it checks the repository alone: harness.json,
    local/harness.json and claude/plugins.json have every required field and
    no key they do not know (keys are case-sensitive), harness.json names
    sources that exist, every JSON file under claude/, contexts/, local/ and
    local.example/ parses, every script parses, and PSScriptAnalyzer (when
    installed) has nothing to say. With -Installed it also checks a home
    directory: every link points into the checkout, every generated
    instruction file carries its header, and every generated settings file
    still matches its sidecar. A {workRoot} target is checked only when a
    work root is known; otherwise it is a note. A source that does not exist
    yet, an analyzer finding and settings drift are warnings; anything else
    wrong is a failure, and the script exits 1.
.PARAMETER HomePath
    The home directory to check with -Installed. Defaults to $HOME.
.PARAMETER Installed
    Also checks the installation in the home directory.
.PARAMETER PersonalRoot
    The folder that holds the personal repositories. Defaults to the one
    saved in local/harness.json.
.PARAMETER WorkRoot
    The folder that holds the work repositories. Defaults to the one saved
    in local/harness.json.
.PARAMETER LocalPath
    The folder that holds this machine's fragments. Defaults to local/ in
    the checkout.
.INPUTS
    None.
.OUTPUTS
    None. A table of results is written to the host.
.EXAMPLE
    ./scripts/Test-Harness.ps1

    Checks the repository before a change is committed.
.EXAMPLE
    ./scripts/Test-Harness.ps1 -Installed

    Also checks the installation in the home directory.
.LINK
    https://github.com/TaffarelJr/ai-harness/blob/main/README.md
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'The results table is for the person at the console, not data.')]
param(
    [string]$HomePath = $HOME,

    [switch]$Installed,

    [string]$PersonalRoot,

    [string]$WorkRoot,

    [string]$LocalPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('pass', 'warn', 'fail', 'note')]
        [string]$Result,

        [Parameter(Mandatory)]
        [string]$Check,

        [Parameter(Mandatory)]
        [string]$Subject,

        [Parameter(Mandatory)]
        [string]$Detail
    )

    $results.Add([PSCustomObject]@{
            Result  = $Result
            Check   = $Check
            Subject = $Subject
            Detail  = $Detail
        })
}

function Add-MissingRootResult {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Row,

        [Parameter(Mandatory)]
        [string]$Target
    )

    if ($Target.Contains('{personalRoot}') -and -not $personalPath) {
        Add-Result @Row -Result warn -Detail 'not checked: no personal root is known'
        return $true
    }

    if ($Target.Contains('{workRoot}') -and -not $workPath) {
        Add-Result @Row -Result note -Detail 'not checked: no work root on this machine'
        return $true
    }

    return $false
}

function Get-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return [IO.Path]::GetRelativePath($root, $Path).Replace('\', '/')
}

$root = Get-HarnessRoot
$localFull = if ($LocalPath) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LocalPath)
}
else {
    Join-Path $root 'local'
}

$manifest = $null
$row = @{
    Check   = 'manifest'
    Subject = 'harness.json'
}
$checked = 'parses, with every required field and no unknown key'
try {
    $manifest = Read-HarnessManifest -Root $root
    Add-Result @row -Result pass -Detail $checked
}
catch {
    Add-Result @row -Result fail -Detail $_.Exception.Message
}

$localConfig = $null
$row = @{
    Check   = 'manifest'
    Subject = 'local/harness.json'
}
try {
    $localConfig = Read-HarnessLocalConfig -LocalPath $localFull
    if ([IO.File]::Exists($localConfig.Path)) {
        Add-Result @row -Result pass -Detail 'parses, with no unknown key'
    }
}
catch {
    Add-Result @row -Result fail -Detail $_.Exception.Message
}

if ($null -ne $manifest -and $manifest.Plugins) {
    $row = @{
        Check   = 'manifest'
        Subject = $manifest.Plugins
    }
    try {
        $path = Resolve-HarnessPath -Path $manifest.Plugins -Root $root -HomePath $root -LocalPath $localFull
        if ([IO.File]::Exists($path)) {
            $null = Read-HarnessPluginManifest -Path $path
            Add-Result @row -Result pass -Detail $checked
        }
    }
    catch {
        Add-Result @row -Result fail -Detail $_.Exception.Message
    }
}

if ($null -ne $manifest) {
    $sources = [System.Collections.Generic.List[string]]::new()
    $named = @(
        $manifest.Links | ForEach-Object { $_.Source }
        $manifest.Instructions | ForEach-Object { $_.Source }
        $manifest.Settings | ForEach-Object { $_.Source }
        $manifest.Plugins
        $manifest.Mcp
    )
    foreach ($source in $named) {
        if ($source -and -not $sources.Contains($source)) {
            $sources.Add($source)
        }
    }

    foreach ($source in $sources) {
        $row = @{
            Check   = 'source'
            Subject = $source
        }
        $path = Resolve-HarnessPath -Path $source -Root $root -HomePath $root
        if ((Get-HarnessItem -Path $path).Kind -in 'File', 'Directory') {
            Add-Result @row -Result pass -Detail 'exists'
        }
        else {
            Add-Result @row -Result warn -Detail 'does not exist yet; its items are skipped'
        }
    }
}

$syncedDir = Join-Path -Path $root -ChildPath 'claude' -AdditionalChildPath 'skills', 'synced'
$syncedPrefix = $syncedDir + [IO.Path]::DirectorySeparatorChar
foreach ($folder in @('claude', 'contexts', 'local', 'local.example')) {
    $private = $folder -ceq 'local'
    $path = if ($private) { $localFull } else { Join-Path $root $folder }
    if (-not [IO.Directory]::Exists($path)) {
        continue
    }

    foreach ($file in Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.json') {
        if ($file.FullName.StartsWith($syncedPrefix, 'OrdinalIgnoreCase')) {
            # claude/skills/synced/ is git-ignored and may hold third-party JSON; not ours to check.
            continue
        }

        $subject = if ($private) {
            'local/' + [IO.Path]::GetRelativePath($localFull, $file.FullName).Replace('\', '/')
        }
        else {
            Get-RelativePath -Path $file.FullName
        }

        $row = @{
            Check   = 'json'
            Subject = $subject
        }
        try {
            $null = Read-HarnessJson -Path $file.FullName -HideDetail:$private
            Add-Result @row -Result pass -Detail 'parses'
        }
        catch {
            $detail = $_.Exception.Message
            if ($private) {
                $detail = 'is not valid JSON (the details are hidden: local/ is private)'
            }

            Add-Result @row -Result fail -Detail $detail
        }
    }
}

# Walk the tree without descending into .git: enumerate root files, then each top folder but .git.
$excluded = @('local/', 'claude/skills/synced/')
$walk = [System.Collections.Generic.List[object]]::new()
$walk.AddRange([object[]]@(Get-ChildItem -LiteralPath $root -File -Force))
foreach ($dir in Get-ChildItem -LiteralPath $root -Directory -Force) {
    if ($dir.Name -cne '.git') {
        $walk.AddRange([object[]]@(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force))
    }
}

$scripts = foreach ($file in $walk) {
    $relative = Get-RelativePath -Path $file.FullName
    $skip = @($excluded | Where-Object { $relative.StartsWith($_, 'Ordinal') }).Count -gt 0
    if ($file.Extension -in '.ps1', '.psm1' -and -not $skip) {
        $file
    }
}

foreach ($file in $scripts) {
    $row = @{
        Check   = 'parse'
        Subject = Get-RelativePath -Path $file.FullName
    }
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -eq 0) {
        Add-Result @row -Result pass -Detail 'parses'
    }
    else {
        $first = $errors[0]
        $detail = "$($errors.Count) errors; line $($first.Extent.StartLineNumber): $($first.Message)"
        Add-Result @row -Result fail -Detail $detail
    }
}

$analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $analyzer) {
    Add-Result -Check 'analyzer' -Subject 'PSScriptAnalyzer' -Result note -Detail 'not installed; not run'
}
else {
    Import-Module $analyzer.Path -Force
    $analyze = @{}
    $settingsFile = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
    if ([IO.File]::Exists($settingsFile)) {
        $analyze.Settings = $settingsFile
    }

    foreach ($file in $scripts) {
        $row = @{
            Check   = 'analyzer'
            Subject = Get-RelativePath -Path $file.FullName
        }
        try {
            $findings = @(Invoke-ScriptAnalyzer -Path $file.FullName @analyze)
        }
        catch {
            Add-Result @row -Result note -Detail "the analyzer failed: $($_.Exception.Message)"
            continue
        }

        if ($findings.Count -eq 0) {
            Add-Result @row -Result pass -Detail 'no findings'
            continue
        }

        $listed = @($findings | Select-Object -First 5 | ForEach-Object { "$($_.RuleName) (line $($_.Line))" })
        $more = if ($findings.Count -gt 5) { ", and $($findings.Count - 5) more" } else { '' }
        Add-Result @row -Result warn -Detail "$($findings.Count) findings: $($listed -join ', ')$more"
    }
}

if ($Installed -and $null -ne $manifest) {
    $homeFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HomePath)
    $personalPath = Resolve-HarnessContextRoot -Path $PersonalRoot
    if (-not $personalPath -and $null -ne $localConfig) {
        $personalPath = $localConfig.PersonalRoot
    }

    if ($personalPath -and -not [IO.Directory]::Exists($personalPath)) {
        $personalPath = $null
    }

    $workPath = Resolve-HarnessContextRoot -Path $WorkRoot
    if (-not $workPath -and $null -ne $localConfig) {
        $workPath = $localConfig.WorkRoot
    }

    if ($workPath -and -not [IO.Directory]::Exists($workPath)) {
        $workPath = $null
    }

    $resolve = @{
        Root         = $root
        HomePath     = $homeFull
        LocalPath    = $localFull
        PersonalRoot = $personalPath
        WorkRoot     = $workPath
    }
    $notInstalled = 'does not exist; run Install-Harness.ps1'

    foreach ($link in $manifest.Links) {
        $row = @{
            Check   = 'link'
            Subject = $link.Target
        }
        try {
            if (Add-MissingRootResult -Row $row -Target $link.Target) {
                continue
            }

            $source = Resolve-HarnessPath -Path $link.Source @resolve
            if ((Get-HarnessItem -Path $source).Kind -eq 'Missing') {
                Add-Result @row -Result warn -Detail "not checked: $($link.Source) does not exist yet"
                continue
            }

            $item = Get-HarnessItem -Path (Resolve-HarnessPath -Path $link.Target @resolve)
            if ($item.Kind -eq 'Link' -and (Test-HarnessSamePath -Left $item.LinkTarget -Right $source)) {
                Add-Result @row -Result pass -Detail "links to $($link.Source)"
            }
            elseif ($item.Kind -eq 'Link') {
                Add-Result @row -Result fail -Detail "links to $($item.LinkTarget), not $($link.Source)"
            }
            elseif ($item.Kind -eq 'Missing') {
                Add-Result @row -Result fail -Detail $notInstalled
            }
            else {
                Add-Result @row -Result fail -Detail "is a $($item.Kind.ToLowerInvariant()), not a link"
            }
        }
        catch {
            Add-Result @row -Result fail -Detail $_.Exception.Message
        }
    }

    foreach ($instruction in $manifest.Instructions) {
        foreach ($targetSpec in $instruction.Targets) {
            $row = @{
                Check   = 'instructions'
                Subject = $targetSpec
            }
            try {
                if (Add-MissingRootResult -Row $row -Target $targetSpec) {
                    continue
                }

                if (-not [IO.File]::Exists((Resolve-HarnessPath -Path $instruction.Source @resolve))) {
                    Add-Result @row -Result warn -Detail "not checked: $($instruction.Source) does not exist yet"
                    continue
                }

                $target = Resolve-HarnessPath -Path $targetSpec @resolve
                $state = Get-HarnessGeneratedState -Path $target
                if (-not $state.Exists) {
                    Add-Result @row -Result fail -Detail $notInstalled
                }
                elseif (-not $state.Generated) {
                    Add-Result @row -Result fail -Detail 'has no generated header, so it was made by hand'
                }
                elseif (-not $state.HashKnown) {
                    Add-Result @row -Result warn -Detail 'an older harness wrote it, without a hash to check'
                }
                elseif ($state.HashMatches) {
                    Add-Result @row -Result pass -Detail 'generated and unedited'
                }
                else {
                    Add-Result @row -Result warn -Detail 'drift: edited below the generated header'
                }
            }
            catch {
                Add-Result @row -Result fail -Detail $_.Exception.Message
            }
        }
    }

    foreach ($setting in $manifest.Settings) {
        $row = @{
            Check   = 'settings'
            Subject = $setting.Target
        }
        try {
            if (Add-MissingRootResult -Row $row -Target $setting.Target) {
                continue
            }

            if (-not [IO.File]::Exists((Resolve-HarnessPath -Path $setting.Source @resolve))) {
                Add-Result @row -Result warn -Detail "not checked: $($setting.Source) does not exist yet"
                continue
            }

            $target = Resolve-HarnessPath -Path $setting.Target @resolve
            $drift = Get-HarnessSettingDrift -Target $target
            switch ($drift.Status) {
                'Missing' { Add-Result @row -Result fail -Detail $notInstalled }
                'NoSidecar' { Add-Result @row -Result fail -Detail 'has no sidecar, so the harness did not write it' }
                'Unreadable' { Add-Result @row -Result fail -Detail $drift.Reason }
                'Clean' { Add-Result @row -Result pass -Detail 'matches its sidecar' }
                default {
                    $n = $drift.Difference.Count
                    $detail = "drift: $n changes since the install; Update-Harness.ps1 lists them"
                    Add-Result @row -Result warn -Detail $detail
                }
            }
        }
        catch {
            Add-Result @row -Result fail -Detail $_.Exception.Message
        }
    }

    $platform = Get-HarnessPlatform
    foreach ($module in $manifest.Modules) {
        $row = @{
            Check   = 'module'
            Subject = $module.Name
        }
        if ($module.Platform -and $module.Platform -cne $platform) {
            Add-Result @row -Result pass -Detail "not for $platform"
        }
        elseif (Get-Module -ListAvailable -Name $module.Name) {
            Add-Result @row -Result pass -Detail 'installed'
        }
        else {
            Add-Result @row -Result warn -Detail 'not installed; run Install-Harness.ps1'
        }
    }
}

$table = $results | Format-Table -Property Result, Check, Subject, Detail -AutoSize -Wrap | Out-String -Width 160
Write-Host $table.TrimEnd()
$counts = $results | Group-Object -Property Result -AsHashTable -AsString
$tally = foreach ($name in 'pass', 'warn', 'note', 'fail') {
    $count = if ($null -ne $counts -and $counts.ContainsKey($name)) { $counts[$name].Count } else { 0 }
    "$count $name"
}

$failed = $null -ne $counts -and $counts.ContainsKey('fail')
$color = if ($failed) { 'Red' } else { 'Green' }
Write-Host ''
Write-Host "Test-Harness: $($tally -join ', ')" -ForegroundColor $color
exit ([int]$failed)

#Requires -Version 7.4

<#
.SYNOPSIS
    Logs a Claude Code event and signals it on this machine with a sound and
    a toast.
.DESCRIPTION
    A Claude Code hook for the Notification and Stop events. It reads the hook
    input from standard input and appends one line to notifications.log in the
    Claude Code configuration folder (CLAUDE_CONFIG_DIR, or ~/.claude): the
    time, the event, the leaf of the working folder and the message, separated
    by tabs. Then it picks a slot from the event - done for Stop, background
    for a completed background session, idle for an idle prompt, attention for
    everything else - and plays that slot's sound the configured number of
    times, with a toast where the OS supports one. The configuration is
    notifications.json beside this script's folder (comments allowed),
    overlaid by local/notifications.json two folders up, both read on every
    run so a change takes effect at once. Nothing is sent over the network,
    and the script always exits 0, so a failure never interrupts the session.
.INPUTS
    System.String. The hook input JSON, on standard input.
.OUTPUTS
    None.
.EXAMPLE
    $hookInput = '{"hook_event_name":"Stop","cwd":"/home/me/src/app"}'
    $hookInput | pwsh -NoProfile -File ./Send-LocalNotification.ps1

    Logs the event and plays the "done" sound.
.LINK
    https://github.com/TaffarelJr/ai-harness/blob/main/README.md
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertFrom-JsonElement {
    [CmdletBinding()]
    [OutputType([hashtable], [object[]], [string], [double], [bool])]
    param(
        [Parameter(Mandatory)]
        [System.Text.Json.JsonElement]$Element
    )

    switch ($Element.ValueKind) {
        'Object' {
            $table = @{}
            foreach ($property in $Element.EnumerateObject()) {
                $table[$property.Name] = ConvertFrom-JsonElement -Element $property.Value
            }

            return $table
        }
        'Array' {
            $list = foreach ($item in $Element.EnumerateArray()) { ConvertFrom-JsonElement -Element $item }
            return , @($list)
        }
        'String' { return $Element.GetString() }
        'Number' { return $Element.GetDouble() }
        'True' { return $true }
        'False' { return $false }
        default { return $null }
    }
}

function Read-JsonFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{}
    }

    # Comments and trailing commas are allowed so the defaults file can explain its own options.
    $options = [System.Text.Json.JsonDocumentOptions]@{
        CommentHandling   = [System.Text.Json.JsonCommentHandling]::Skip
        AllowTrailingCommas = $true
    }
    $document = [System.Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($Path), $options)
    try {
        $value = ConvertFrom-JsonElement -Element $document.RootElement
        if ($value -is [hashtable]) {
            return $value
        }

        Write-Warning "$Path does not hold a JSON object; ignoring it."
        return @{}
    }
    finally {
        $document.Dispose()
    }
}

function Merge-Setting {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Base,

        [Parameter(Mandatory)]
        [hashtable]$Overlay
    )

    $merged = $Base.Clone()
    foreach ($key in $Overlay.Keys) {
        $value = $Overlay[$key]
        if ($value -is [hashtable] -and $merged[$key] -is [hashtable]) {
            $merged[$key] = Merge-Setting -Base $merged[$key] -Overlay $value
        }
        else {
            $merged[$key] = $value
        }
    }

    return $merged
}

function Get-Setting {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$HookFolder
    )

    $defaults = Read-JsonFile -Path ([IO.Path]::Combine($HookFolder, '..', 'notifications.json'))
    $local = Read-JsonFile -Path ([IO.Path]::Combine($HookFolder, '..', '..', 'local', 'notifications.json'))
    return Merge-Setting -Base $defaults -Overlay $local
}

function Get-Field {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Data -is [System.Collections.IDictionary] -and $Data[$Name] -is [string]) {
        return ($Data[$Name] -replace '[\t\r\n]+', ' ').Trim()
    }

    return ''
}

function Get-Number {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [AllowNull()]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [double]$Default
    )

    if ($Data -is [System.Collections.IDictionary] -and $Data[$Name] -is [double] -and $Data[$Name] -ge 0) {
        return [double]$Data[$Name]
    }

    return $Default
}

function Get-Slot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Data
    )

    if ((Get-Field -Data $Data -Name 'hook_event_name') -ceq 'Stop') {
        return 'Done'
    }

    switch (Get-Field -Data $Data -Name 'notification_type') {
        'agent_completed' { return 'Background' }
        'idle_prompt' { return 'Idle' }
        default { return 'Attention' }
    }
}

function Get-SoundFolder {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($IsWindows) {
        return Join-Path -Path $env:SystemRoot -ChildPath 'Media'
    }

    if ($IsMacOS) {
        return '/System/Library/Sounds'
    }

    return '/usr/share/sounds/freedesktop/stereo'
}

function Resolve-SoundPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$SlotSetting,

        [Parameter(Mandatory)]
        [string]$Slot
    )

    if ($SlotSetting -isnot [hashtable]) {
        return
    }

    $file = $SlotSetting['File']
    if ($file -is [hashtable]) {
        $os = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'MacOS' } else { 'Linux' }
        $file = $file[$os]
    }

    if ($file -isnot [string] -or [string]::IsNullOrWhiteSpace($file)) {
        return
    }

    $path = if ([IO.Path]::IsPathRooted($file)) { $file } else { Join-Path -Path (Get-SoundFolder) -ChildPath $file }
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return $path
    }

    Write-Warning "The sound for '$Slot' was not found at $path."
}

function Invoke-Sound {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($IsWindows) {
        $player = [System.Media.SoundPlayer]::new($Path)
        $player.PlaySync()
        return
    }

    $command = if ($IsMacOS) { 'afplay' } else { 'paplay' }
    $tool = Get-Command -Name $command -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($null -eq $tool -and -not $IsMacOS) {
        $tool = Get-Command -Name 'aplay' -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    }

    if ($null -ne $tool) {
        & $tool.Source $Path
        return
    }

    [Console]::Beep()
}

function Show-Toast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message
    )

    $text = @($Title, $Message | Where-Object { $_ })
    if ($IsWindows -and (Get-Module -ListAvailable -Name BurntToast)) {
        Import-Module BurntToast
        # Silent: the sound is ours to choose and repeat; the toast is the visual half.
        New-BurntToastNotification -Text $text -Silent
        return
    }

    $notifySend = Get-Command -Name 'notify-send' -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($IsLinux -and $null -ne $notifySend) {
        $arguments = @('--') + $text
        & $notifySend.Source @arguments
    }
}

$data = $null
try {
    $raw = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $document = [System.Text.Json.JsonDocument]::Parse($raw)
        try {
            $data = ConvertFrom-JsonElement -Element $document.RootElement
        }
        finally {
            $document.Dispose()
        }
    }
}
catch {
    [Console]::Error.WriteLine("Send-LocalNotification: the hook input is not JSON: $($_.Exception.Message)")
}

$slot = Get-Slot -Data $data
$cwd = Get-Field -Data $data -Name 'cwd'
$folder = [IO.Path]::GetFileName($cwd.TrimEnd('\', '/'))
$message = Get-Field -Data $data -Name 'message'
$title = Get-Field -Data $data -Name 'title'
if (-not $title) {
    $title = switch ($slot) {
        'Done' { 'Claude finished' }
        'Background' { 'A background session finished' }
        'Idle' { 'Claude is waiting for you' }
        default { 'Claude needs you' }
    }
}

if ($folder) {
    $title = "$title - $folder"
}

try {
    $configFolder = $env:CLAUDE_CONFIG_DIR
    if (-not $configFolder) {
        $configFolder = Join-Path -Path $HOME -ChildPath '.claude'
    }

    $fields = @(
        [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz', [CultureInfo]::InvariantCulture)
        $slot
        (Get-Field -Data $data -Name 'hook_event_name') + '/' + (Get-Field -Data $data -Name 'notification_type')
        $folder
        $message
    )
    $null = [IO.Directory]::CreateDirectory($configFolder)
    $line = ($fields -join "`t") + [Environment]::NewLine
    $logPath = Join-Path -Path $configFolder -ChildPath 'notifications.log'
    [IO.File]::AppendAllText($logPath, $line, [Text.UTF8Encoding]::new($false))
}
catch {
    [Console]::Error.WriteLine("Send-LocalNotification could not write the log: $($_.Exception.Message)")
}

try {
    $setting = Get-Setting -HookFolder $PSScriptRoot
    if ($setting['Quiet'] -eq $true) {
        exit 0
    }

    if ($setting['Toast'] -ne $false) {
        try {
            Show-Toast -Title $title -Message $message
        }
        catch {
            [Console]::Error.WriteLine("Send-LocalNotification could not show a toast: $($_.Exception.Message)")
        }
    }

    $slotSetting = if ($setting['Sounds'] -is [hashtable]) { $setting['Sounds'][$slot] } else { $null }
    $path = Resolve-SoundPath -SlotSetting $slotSetting -Slot $slot
    if (-not $path) {
        [Console]::Beep()
        exit 0
    }

    # The hook's timeout in settings.json is the only ceiling on a long sequence.
    $count = Get-Number -Data $slotSetting -Name 'Repeat' -Default 1
    for ($i = 0; $i -lt $count; $i++) {
        if ($i -gt 0) {
            Start-Sleep -Milliseconds 400
        }

        Invoke-Sound -Path $path
    }
}
catch {
    [Console]::Error.WriteLine("Send-LocalNotification could not signal: $($_.Exception.Message)")
}

exit 0

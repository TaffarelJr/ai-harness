#Requires -Version 7.4

<#
.SYNOPSIS
    Checks the decision Block-DangerousGit.ps1 makes for each command in a table.
.DESCRIPTION
    Feeds each command to the hook as PreToolUse input, in a child process with
    a clean override variable, and compares the outcome with the expected one:
    ask (a permission prompt with a reason) or pass (no output). The hook must
    never deny or fail. Prints one line per failing case and a summary, and
    exits 1 if any case fails.
.EXAMPLE
    ./tests/Block-DangerousGit.Tests.ps1

    Runs every case.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$hook = [IO.Path]::Combine($PSScriptRoot, '..', 'claude', 'hooks', 'Block-DangerousGit.ps1')
$heredoc = "git commit -F - <<'EOF'`nfix: tidy the docs`n`nNever run gh pr merge yourself.`nEOF"

$cases = @(
    # Force-pushes and deletions aimed at the default branch, or at no branch.
    @{ Expect = 'ask'; Command = 'git push --force origin main' }
    @{ Expect = 'ask'; Command = 'git push -f origin master' }
    @{ Expect = 'ask'; Command = 'git push origin +main' }
    @{ Expect = 'ask'; Command = 'git push --delete origin main' }
    @{ Expect = 'ask'; Command = 'git push origin :refs/heads/main' }
    @{ Expect = 'ask'; Command = 'git push --force' }
    @{ Expect = 'ask'; Command = 'git push -f origin' }
    @{ Expect = 'ask'; Command = 'git push -f origin HEAD' }
    @{ Expect = 'ask'; Command = 'git push --mirror origin' }
    @{ Expect = 'ask'; Command = 'git push --prune origin' }
    @{ Expect = 'ask'; Command = 'git push --force --all origin' }
    @{ Expect = 'ask'; Command = 'git -C ../repo push --force-with-lease origin main' }
    @{ Expect = 'ask'; Command = 'cd repo && git push -f origin main' }
    @{ Expect = 'ask'; Command = '(git push -f origin main)' }
    @{ Expect = 'ask'; Command = "git push \`n  --force origin main" }
    @{ Expect = 'ask'; Command = 'git branch -D main' }
    @{ Expect = 'ask'; Command = 'git branch -M main' }
    @{ Expect = 'ask'; Command = 'git -C repo branch --delete --force master' }
    @{ Expect = 'ask'; Command = 'git branch -D refs/heads/main' }

    # Merging a pull request, directly or through the API.
    @{ Expect = 'ask'; Command = 'gh pr merge 12 --squash' }
    @{ Expect = 'ask'; Command = 'gh pr merge --rebase --delete-branch' }
    @{ Expect = 'ask'; Command = 'gh -R owner/repo pr merge 12' }
    @{ Expect = 'ask'; Command = 'gh pr --repo owner/repo merge 12' }
    @{ Expect = 'ask'; Command = 'gh api -X PUT repos/owner/repo/pulls/12/merge' }
    @{ Expect = 'ask'; Command = 'gh api --method=DELETE repos/owner/repo/git/refs/heads/feature' }
    @{ Expect = 'ask'; Command = "gh api graphql -f query='mutation { mergePullRequest(input: {}) { clientMutationId } }'" }
    @{ Expect = 'ask'; Command = 'gh api graphql -F query=@mutation.graphql' }
    @{ Expect = 'ask'; Command = $heredoc }

    # Anything that hides what runs.
    @{ Expect = 'ask'; Command = "gh alias set pm 'pr merge'" }
    @{ Expect = 'ask'; Command = 'git -c alias.p=push p origin main' }
    @{ Expect = 'ask'; Command = 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.x GIT_CONFIG_VALUE_0=push git x' }
    @{ Expect = 'ask'; Command = '$env:GIT_CONFIG_COUNT = ''1''; git x'; Tool = 'PowerShell' }
    @{ Expect = 'ask'; Command = 'eval "$cmd"' }
    @{ Expect = 'ask'; Command = 'git ls-files | xargs git rm' }
    @{ Expect = 'ask'; Command = 'Invoke-Expression $command'; Tool = 'PowerShell' }
    @{ Expect = 'ask'; Command = 'iex $command'; Tool = 'PowerShell' }
    @{ Expect = 'ask'; Command = 'Start-Process git -ArgumentList ''push'''; Tool = 'PowerShell' }
    @{ Expect = 'ask'; Command = 'pwsh -e SQBFAFgA' }
    @{ Expect = 'ask'; Command = 'pwsh -NoProfile -enc SQBFAFgA' }
    @{ Expect = 'ask'; Command = 'powershell.exe -NoProfile -EncodedCommand SQBFAFgA' }
    @{ Expect = 'ask'; Command = 'powershell -ec SQBFAFgA' }
    @{ Expect = 'ask'; Command = 'echo SQBFAFgA | base64 -d | sh' }

    # Ordinary work on feature branches.
    @{ Expect = 'pass'; Command = 'git push --force-with-lease origin feat/x' }
    @{ Expect = 'pass'; Command = 'git push -f origin feature' }
    @{ Expect = 'pass'; Command = 'git push origin feature' }
    @{ Expect = 'pass'; Command = 'git push --delete origin spike/old' }
    @{ Expect = 'pass'; Command = 'git push origin :spike/old' }
    @{ Expect = 'pass'; Command = 'git push --atomic --force-with-lease=a:1 --force-with-lease=b:2 origin a b' }
    @{ Expect = 'pass'; Command = 'git push "--force-with-lease=$($branch):$($sha)" origin $branch 2>&1 | Select-Object -Last 1'; Tool = 'PowerShell' }
    @{ Expect = 'pass'; Command = 'git branch -D feat/x' }
    @{ Expect = 'pass'; Command = 'git branch -d main' }

    # False positives seen in real sessions: long paths, prose, searches, scripts.
    @{ Expect = 'pass'; Command = 'git diff -U4 origin/main...feature -- src/Contoso.Analytics.Api/Infrastructure/Repositories/CustomerRepository.cs' }
    @{ Expect = 'pass'; Command = 'git add src/Contoso.Configuration/Validation/RequiredWithAttribute.cs && git commit -F msg.txt' }
    @{ Expect = 'pass'; Command = 'mkdir -p "/c/Users/someone/AppData/Local/Temp/harness-map" && git status --short' }
    @{ Expect = 'pass'; Command = 'git show 0123456789abcdef0123456789abcdef01234567:src/ApplicationUsers/RequestHandlers/GetProfileRequestHandler.cs' }
    @{ Expect = 'pass'; Command = 'gh pr view 12 --json title,mergeable,mergeStateStatus' }
    @{ Expect = 'pass'; Command = 'for n in 1 2; do gh pr view $n --json state; done; echo "merge them later by hand"' }
    @{ Expect = 'pass'; Command = "grep -rniE 'git merge|git push|gh pr|--draft' skills" }
    @{ Expect = 'pass'; Command = 'gh pr checks 12; echo "then merge by hand"' }
    @{ Expect = 'pass'; Command = 'GIT_CONFIG_GLOBAL=/tmp/gitconfig GIT_CONFIG_NOSYSTEM=1 git commit -m x' }
    @{ Expect = 'pass'; Command = "set -e`ncd /x && pwsh -NoProfile -Command 'Get-Date'" }
    @{ Expect = 'pass'; Command = 'pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1' }
    @{ Expect = 'pass'; Command = 'grep -e pattern file.txt; pwsh -NoProfile -Command "1"' }
    @{ Expect = 'pass'; Command = "`$o = `$line | ConvertFrom-Json -Depth 30`n'a settings fix can be an independent branch off main'"; Tool = 'PowerShell' }
    @{ Expect = 'pass'; Command = 'git branch --show-current; echo main' }
    @{ Expect = 'pass'; Command = 'Get-Module -Name x; git branch --list main'; Tool = 'PowerShell' }
    @{ Expect = 'pass'; Command = 'try { $o = $resp | ConvertFrom-Json } catch { "push failed: " + $_; return }'; Tool = 'PowerShell' }
    @{ Expect = 'pass'; Command = 'if ($a -and $b) { git push origin feature }'; Tool = 'PowerShell' }
    @{ Expect = 'pass'; Command = 'Remove-Item -LiteralPath $dir -Recurse -Force'; Tool = 'PowerShell' }
    @{ Expect = 'pass'; Command = 'Get-ChildItem | Where-Object { $_.Name -match ''evaluation'' }'; Tool = 'PowerShell' }

    # Text cannot tell a quoted pattern from a command handed to bash -c, so both ask.
    @{ Expect = 'ask'; Command = "grep -rn 'git push --force origin main' docs" }
    @{ Expect = 'ask'; Command = "bash -c 'git push --force origin main'" }

    # The override lets history rewrites pass, but never a merge.
    @{ Expect = 'pass'; Command = 'git push -f origin main'; Override = '1' }
    @{ Expect = 'pass'; Command = 'git branch -D main'; Override = 'true' }
    @{ Expect = 'ask'; Command = 'gh pr merge 12 --squash'; Override = '1' }

    # Input the hook does not judge, and input it cannot read.
    @{ Expect = 'pass'; Raw = '{"tool_name":"Read","tool_input":{"file_path":"x"}}'; Name = 'a tool other than a shell' }
    @{ Expect = 'pass'; Raw = ''; Name = 'empty input' }
    @{ Expect = 'ask'; Raw = '{not json'; Name = 'input that is not JSON' }
)

$failed = 0
$saved = $env:AI_HARNESS_ALLOW_HISTORY_REWRITE
try {
    foreach ($case in $cases) {
        $tool = if ($case.ContainsKey('Tool')) { $case.Tool } else { 'Bash' }
        $json = if ($case.ContainsKey('Raw')) {
            $case.Raw
        }
        else {
            @{ tool_name = $tool; tool_input = @{ command = $case.Command } } | ConvertTo-Json -Compress
        }

        $env:AI_HARNESS_ALLOW_HISTORY_REWRITE = if ($case.ContainsKey('Override')) { $case.Override } else { $null }
        $output = @($json | pwsh -NoProfile -File $hook 2>$null)
        $exitCode = $LASTEXITCODE
        $text = $output -join "`n"

        $actual = if ($exitCode -ne 0) {
            "exit $exitCode"
        }
        elseif ($text -match '"permissionDecision":"ask"') {
            'ask'
        }
        elseif ($text -match '"permissionDecision"') {
            'other decision'
        }
        elseif ($text) {
            'unexpected output'
        }
        else {
            'pass'
        }

        if ($actual -cne $case.Expect) {
            $failed++
            $label = if ($case.ContainsKey('Name')) { $case.Name } else { $case.Command -replace '\r?\n', ' / ' }
            Write-Output "FAIL expected $($case.Expect), got ${actual}: $label"
        }
    }
}
finally {
    $env:AI_HARNESS_ALLOW_HISTORY_REWRITE = $saved
}

Write-Output "Block-DangerousGit: $($cases.Count - $failed) passed, $failed failed"
if ($failed -gt 0) {
    exit 1
}

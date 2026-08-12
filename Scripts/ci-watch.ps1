#Requires -Version 5.1
<#
.SYNOPSIS
    Trigger the Resonance GitHub Actions build, poll until done, and dump
    logs on failure.

.DESCRIPTION
    Wraps gh so the typical run workflow -> wait -> fix errors loop becomes
    a single command. On success, optionally downloads the IPA artifact.
    On failure, prints the relevant slice of the build log so you can
    paste it back to Claude.

.PARAMETER Workflow
    Workflow file name (default: "sideload-ipa.yml").

.PARAMETER Signing
    signing input to pass through (adhoc | development). Default: adhoc.

.PARAMETER Download
    When the run succeeds, also download the IPA artifact.

.PARAMETER DownloadPath
    Directory to download artifacts into (default: build/ci-artifacts).

.EXAMPLE
    .\Scripts\ci-watch.ps1
    .\Scripts\ci-watch.ps1 -Signing development -Download
    .\Scripts\ci-watch.ps1 -Workflow simulator-ipa.yml

.NOTES
    Requires: GitHub CLI (gh) authenticated with gh auth login and scope
    repo + workflow. Alternatively, set $env:GITHUB_TOKEN before running.
#>

[CmdletBinding()]
param(
    [string]$Workflow = 'sideload-ipa.yml',
    [ValidateSet('adhoc','development','ad-hoc','simulator')]
    [string]$Signing = 'adhoc',
    [switch]$Download,
    [string]$DownloadPath = 'build/ci-artifacts'
)

$ErrorActionPreference = 'Stop'

# -------------------------------------------------------------------------
# PowerShell 5.1 quirk: every native gh invocation that returns a non-zero
# exit code wraps it in a NativeCommandError that aborts the script under
# $ErrorActionPreference='Stop'. Wrap them in Invoke-Gh which:
#   * relaxes ErrorActionPreference for the duration of the call
#   * captures stdout+stderr into a string
#   * sets $script:LAST_GH_EXIT so callers can branch on it
# -------------------------------------------------------------------------
function Invoke-Gh {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & gh @Args 2>&1 | Out-String
    } catch {
        $output = $_.Exception.Message
    } finally {
        $ErrorActionPreference = $prev
    }
    $script:LAST_GH_EXIT = $LASTEXITCODE
    return $output
}

function Test-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "[X] gh CLI not found. Install from https://cli.github.com" -ForegroundColor Red
        exit 1
    }
    if ($env:GITHUB_TOKEN -or $env:GH_TOKEN) {
        # gh auto-picks up either token env var.
        return
    }
    $null = Invoke-Gh auth status
    if ($script:LAST_GH_EXIT -ne 0) {
        Write-Host "[X] gh is not authenticated. Either:" -ForegroundColor Red
        Write-Host "    gh auth login    (scopes: repo, workflow)" -ForegroundColor Red
        Write-Host "    `$env:GITHUB_TOKEN = 'ghp_...'; .\Scripts\ci-watch.ps1" -ForegroundColor Red
        exit 2
    }
}

function Get-LatestRunFor([string]$wf) {
    $raw = Invoke-Gh run list --workflow $wf --limit 1 --json databaseId,status,conclusion,displayTitle,createdAt,headBranch,event,url
    if ($script:LAST_GH_EXIT -ne 0) { return $null }
    try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Watch-Run([long]$runId) {
    Write-Host "[i] Watching run $runId ..." -ForegroundColor Cyan
    while ($true) {
        $raw = Invoke-Gh run view $runId --json status,conclusion,displayTitle,url,headBranch
        $run = $null
        if ($script:LAST_GH_EXIT -eq 0) {
            try { $run = $raw | ConvertFrom-Json } catch {}
        }
        if (-not $run -or -not $run.status) {
            Write-Host "  . (no response from gh yet) -- waiting 15 s" -ForegroundColor DarkGray
            Start-Sleep -Seconds 15
            continue
        }
        switch ($run.status) {
            'completed' {
                $color = if ($run.conclusion -eq 'success') { 'Green' } else { 'Red' }
                Write-Host "[=] Run finished: $($run.conclusion)" -ForegroundColor $color
                return $run
            }
            'in_progress' { Write-Host "  . in_progress -- waiting 15 s" -ForegroundColor DarkGray }
            'queued'      { Write-Host "  . queued      -- waiting 15 s" -ForegroundColor DarkGray }
            'waiting'     { Write-Host "  . waiting     -- waiting 15 s" -ForegroundColor DarkGray }
            'pending'     { Write-Host "  . pending     -- waiting 15 s" -ForegroundColor DarkGray }
            default       { Write-Host "  . $($run.status) -- waiting 15 s" -ForegroundColor DarkGray }
        }
        Start-Sleep -Seconds 15
    }
}

function Show-FailureSummary([long]$runId) {
    Write-Host ""
    Write-Host "=== Failure summary ===" -ForegroundColor Red
    Write-Host ""

    Write-Host "[i] Steps:" -ForegroundColor Yellow
    $stepsRaw = Invoke-Gh run view $runId --json jobs,name,conclusion,steps --jq '.jobs[] | "  [\(.conclusion)] \(.name)]"'
    Write-Host $stepsRaw

    Write-Host ""
    Write-Host "[i] Failed-step logs (most recent 250 lines each):" -ForegroundColor Yellow
    $jobsRaw = Invoke-Gh api "runs/$runId/jobs"
    if ($script:LAST_GH_EXIT -ne 0) {
        Write-Host "(could not list jobs: $jobsRaw)" -ForegroundColor DarkYellow
        return
    }
    try { $jobs = $jobsRaw | ConvertFrom-Json } catch { return }
    foreach ($job in $jobs.jobs) {
        if ($job.conclusion -in 'failure','cancelled','timed_out') {
            Write-Host ""
            Write-Host "----- $($job.name) -----" -ForegroundColor Magenta
            $log = Invoke-Gh run view $runId --job $job.databaseId --log
            if ($script:LAST_GH_EXIT -ne 0) {
                Write-Host "(could not fetch job log)" -ForegroundColor DarkYellow
                continue
            }
            $log -split "`n" | Select-Object -Last 250 | ForEach-Object { Write-Host $_ }
        }
    }
}

function Copy-Artifact([long]$runId, [string]$dest) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Write-Host "[i] Downloading artifact(s) to $dest" -ForegroundColor Cyan
    $dlOut = Invoke-Gh run download $runId --dir $dest
    if ($script:LAST_GH_EXIT -ne 0) {
        Write-Host "(artifact download failed)" -ForegroundColor DarkYellow
        return
    }
    $found = $false
    Get-ChildItem -Path $dest -Recurse -Filter '*.ipa' -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $found) {
            Write-Host ""
            Write-Host "[OK] IPA ready:" -ForegroundColor Green
            $found = $true
        }
        Write-Host "    $($_.FullName)"
    }
    if (-not $found) {
        Write-Host "(no .ipa found in artifacts)" -ForegroundColor DarkYellow
    }
}

# ----- main ------------------------------------------------------------
Test-Gh
$signingArg = if ($Signing -eq 'ad-hoc') { 'adhoc' } else { $Signing }

Write-Host "[i] Triggering workflow '$Workflow' (signing=$signingArg)" -ForegroundColor Cyan
$branch = git rev-parse --abbrev-ref HEAD 2>$null
$trigger = Invoke-Gh workflow run $Workflow --ref $branch -f signing=$signingArg
if ($script:LAST_GH_EXIT -ne 0) {
    Write-Host $trigger
    exit 3
}

# gh workflow run prints the run URL on stdout (something like
# https://github.com/owner/repo/actions/runs/<id>). Prefer that over a
# list filter because two workflows in this repo share the display name
# "Build IPA" and the filter would be ambiguous.
$runUrl = ($trigger -split "`n" | Where-Object { $_ -match 'https?://.*actions/runs/' } | Select-Object -First 1)
if (-not $runUrl) {
    Write-Host "[X] gh workflow run did not print a run URL. Output was:" -ForegroundColor Red
    Write-Host $trigger
    exit 4
}
if ($runUrl -match '/runs/(\d+)') { $runId = [long]$Matches[1] } else { $runId = 0 }
if ($runId -le 0) {
    Write-Host "[X] Could not parse run id from URL: $runUrl" -ForegroundColor Red
    exit 4
}
Write-Host "[i] Run URL: $runUrl" -ForegroundColor Cyan

$final = Watch-Run $runId

if ($final.conclusion -eq 'success') {
    if ($Download) { Copy-Artifact $runId $DownloadPath }
    exit 0
}

Show-FailureSummary $runId
Write-Host ""
Write-Host "-> Paste the output above (or just the failing step's tail)" -ForegroundColor Cyan
Write-Host "   back to Claude to start the auto-fix loop." -ForegroundColor Cyan
exit 10

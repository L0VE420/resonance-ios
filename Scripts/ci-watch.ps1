#Requires -Version 5.1
<#
.SYNOPSIS
    Trigger the Resonance GitHub Actions build, poll until done, and dump
    logs on failure.

.DESCRIPTION
    Wraps `gh` so the typical "run workflow → wait → fix errors" loop
    becomes a single command. On success, optionally downloads the IPA
    artifact. On failure, prints the relevant slice of the build log so
    you can paste it back to Claude.

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
    Requires: GitHub CLI (gh) authenticated with `gh auth login` and
    scope `repo` + `workflow`.
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

function Test-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "✗ gh CLI not found. Install from https://cli.github.com" -ForegroundColor Red
        exit 1
    }
    $status = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ gh is not authenticated. Run: gh auth login" -ForegroundColor Red
        Write-Host $status
        exit 2
    }
}

function Convert-Signing([string]$s) {
    if ($s -eq 'ad-hoc') { return 'adhoc' }
    return $s
}

function Get-LatestRunFor([string]$wf) {
    gh run list --workflow $wf --limit 1 --json databaseId,status,conclusion,displayTitle,createdAt,headBranch,event,url | ConvertFrom-Json
}

function Watch-Run([long]$runId) {
    Write-Host "▶ Watching run $runId …" -ForegroundColor Cyan
    while ($true) {
        $run = gh run view $runId --json status,conclusion,displayTitle,url,headBranch 2>&1 | ConvertFrom-Json
        switch ($run.status) {
            'completed' {
                Write-Host "✓ Run finished: $($run.conclusion)" -ForegroundColor $(if ($run.conclusion -eq 'success') {'Green'} else {'Red'})
                return $run
            }
            'in_progress'  { Write-Host "  · in_progress — waiting 15 s" -ForegroundColor DarkGray }
            'queued'       { Write-Host "  · queued      — waiting 15 s" -ForegroundColor DarkGray }
            'waiting'      { Write-Host "  · waiting     — waiting 15 s" -ForegroundColor DarkGray }
            'pending'      { Write-Host "  · pending     — waiting 15 s" -ForegroundColor DarkGray }
            default        { Write-Host "  · $($run.status) — waiting 15 s" -ForegroundColor DarkGray }
        }
        Start-Sleep -Seconds 15
    }
}

function Show-FailureSummary([long]$runId) {
    Write-Host ""
    Write-Host "=== Failure summary ===" -ForegroundColor Red
    Write-Host ""

    # Step-level summary first — easy to scan.
    Write-Host "▶ Steps:" -ForegroundColor Yellow
    gh run view $runId --json jobs,name,conclusion,steps --jq '.jobs[] | "  [\(.conclusion)] \(.name)"' 2>&1 |
        ForEach-Object { Write-Host $_ }

    Write-Host ""
    Write-Host "▶ Failed-step logs (most recent 250 lines each):" -ForegroundColor Yellow
    $jobs = gh api "runs/$runId/jobs" 2>&1 | ConvertFrom-Json
    foreach ($job in $jobs.jobs) {
        if ($job.conclusion -in 'failure','cancelled','timed_out') {
            Write-Host ""
            Write-Host "----- $($job.name) -----" -ForegroundColor Magenta
            gh run view $runId --job $job.databaseId --log 2>&1 |
                Select-Object -Last 250 |
                ForEach-Object { Write-Host $_ }
        }
    }
}

function Copy-Artifact([long]$runId, [string]$dest) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Write-Host "▶ Downloading artifact(s) to $dest" -ForegroundColor Cyan
    gh run download $runId --dir $dest 2>&1 | ForEach-Object { Write-Host "  $_" }
    $ipas = Get-ChildItem -Path $dest -Recurse -Filter '*.ipa' -ErrorAction SilentlyContinue
    if ($ipas) {
        Write-Host ""
        Write-Host "✓ IPA ready:" -ForegroundColor Green
        $ipas | ForEach-Object { Write-Host "    $($_.FullName)" }
    } else {
        Write-Host "(no .ipa found in artifacts)" -ForegroundColor DarkYellow
    }
}

# ----- main ------------------------------------------------------------
Test-Gh
$signingArg = Convert-Signing $Signing

Write-Host "▶ Triggering workflow '$Workflow' (signing=$signingArg)" -ForegroundColor Cyan
$trigger = gh workflow run $Workflow --ref $(git rev-parse --abbrev-ref HEAD) -f signing=$signingArg 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host $trigger
    exit 3
}

# gh workflow run returns immediately; give it a moment to register, then
# pull the run id of the most recent invocation of this workflow.
Start-Sleep -Seconds 5
$run = Get-LatestRunFor $Workflow
if (-not $run) {
    Write-Host "✗ No run found for $Workflow after trigger" -ForegroundColor Red
    exit 4
}
$runId = $run.databaseId
Write-Host "▶ Run URL: $($run.url)" -ForegroundColor Cyan

$final = Watch-Run $runId

if ($final.conclusion -eq 'success') {
    if ($Download) { Copy-Artifact $runId $DownloadPath }
    exit 0
}

Show-FailureSummary $runId
Write-Host ""
Write-Host "→ Paste the output above (or just the failing step's tail)" -ForegroundColor Cyan
Write-Host "  back to Claude to start the auto-fix loop." -ForegroundColor Cyan
exit 10

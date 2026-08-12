#Requires -Version 5.1
<#
.SYNOPSIS
    Print the failure log of the most recent failed Resonance build.

.DESCRIPTION
    Use this when you've already kicked off a build (manually from the
    GitHub UI, or via ci-watch.ps1) and just want the log dump to feed
    back to Claude.

.EXAMPLE
    .\Scripts\ci-debug.ps1                 # last failed run of sideload-ipa.yml
    .\Scripts\ci-debug.ps1 -Workflow ipa.yml -RunId 1234567890
#>

[CmdletBinding()]
param(
    [string]$Workflow = 'sideload-ipa.yml',
    [long]$RunId = 0
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "✗ gh not found" -ForegroundColor Red; exit 1
}
if (-not (gh auth status >/dev/null 2>&1)) {
    Write-Host "✗ gh not authenticated" -ForegroundColor Red; exit 2
}

if ($RunId -le 0) {
    $run = gh run list --workflow $Workflow --limit 20 --json databaseId,conclusion,displayTitle,createdAt,headBranch,url |
        ConvertFrom-Json |
        Where-Object { $_.conclusion -in 'failure','cancelled','timed_out' } |
        Select-Object -First 1
    if (-not $run) {
        Write-Host "No failed runs in the last 20 for $Workflow" -ForegroundColor Yellow
        exit 0
    }
    $RunId = $run.databaseId
    Write-Host "▶ Latest failed run: $($run.displayTitle) ($RunId) on $($run.headBranch)" -ForegroundColor Cyan
    Write-Host "  $($run.url)"
}

Write-Host ""
Write-Host "=== Steps ==="
gh run view $RunId --json jobs,name,conclusion,steps --jq '.jobs[] | "  [\(.conclusion)] \(.name)"' 2>&1 |
    ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "=== Failed-step logs ==="
$jobs = gh api "runs/$RunId/jobs" 2>&1 | ConvertFrom-Json
foreach ($job in $jobs.jobs) {
    if ($job.conclusion -in 'failure','cancelled','timed_out') {
        Write-Host ""
        Write-Host "----- $($job.name) -----" -ForegroundColor Magenta
        gh run view $RunId --job $job.databaseId --log 2>&1 |
            Select-Object -Last 250 |
            ForEach-Object { Write-Host $_ }
    }
}

Write-Host ""
Write-Host "→ Copy the section above into your chat with Claude." -ForegroundColor Cyan

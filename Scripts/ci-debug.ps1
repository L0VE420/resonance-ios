#Requires -Version 5.1
<#
.SYNOPSIS
    Print the failure log of the most recent failed Resonance build.

.DESCRIPTION
    Use this when you have already kicked off a build (manually from the
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

# Same PowerShell 5.1 native-error wrapping as ci-watch.ps1.
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

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "[X] gh not found" -ForegroundColor Red; exit 1
}
if (-not $env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
    $null = Invoke-Gh auth status
    if ($script:LAST_GH_EXIT -ne 0) {
        Write-Host "[X] gh not authenticated and no GITHUB_TOKEN / GH_TOKEN env var is set." -ForegroundColor Red
        Write-Host "    gh auth login    (scopes: repo, workflow)" -ForegroundColor Red
        Write-Host "    `$env:GITHUB_TOKEN = 'ghp_...'; .\Scripts\ci-debug.ps1" -ForegroundColor Red
        exit 2
    }
}

if ($RunId -le 0) {
    $raw = Invoke-Gh run list --workflow $Workflow --limit 20 --json databaseId,conclusion,displayTitle,createdAt,headBranch,url
    if ($script:LAST_GH_EXIT -ne 0) {
        Write-Host "[X] Could not list runs: $raw" -ForegroundColor Red
        exit 3
    }
    $run = $raw | ConvertFrom-Json |
        Where-Object { $_.conclusion -in 'failure','cancelled','timed_out' } |
        Select-Object -First 1
    if (-not $run) {
        Write-Host "No failed runs in the last 20 for $Workflow" -ForegroundColor Yellow
        exit 0
    }
    $RunId = $run.databaseId
    Write-Host "[i] Latest failed run: $($run.displayTitle) ($RunId) on $($run.headBranch)" -ForegroundColor Cyan
    Write-Host "  $($run.url)"
}

Write-Host ""
Write-Host "=== Steps ==="
$stepsRaw = Invoke-Gh run view $RunId --json jobs,name,conclusion,steps --jq '.jobs[] | "  [\(.conclusion)] \(.name)]"'
Write-Host $stepsRaw

Write-Host ""
Write-Host "=== Failed-step logs ==="
$jobsRaw = Invoke-Gh api "runs/$RunId/jobs"
if ($script:LAST_GH_EXIT -ne 0) {
    Write-Host "(could not list jobs: $jobsRaw)" -ForegroundColor DarkYellow
    exit 4
}
$jobs = $jobsRaw | ConvertFrom-Json
foreach ($job in $jobs.jobs) {
    if ($job.conclusion -in 'failure','cancelled','timed_out') {
        Write-Host ""
        Write-Host "----- $($job.name) -----" -ForegroundColor Magenta
        $log = Invoke-Gh run view $RunId --job $job.databaseId --log
        if ($script:LAST_GH_EXIT -ne 0) {
            Write-Host "(could not fetch job log)" -ForegroundColor DarkYellow
            continue
        }
        $log -split "`n" | Select-Object -Last 250 | ForEach-Object { Write-Host $_ }
    }
}

Write-Host ""
Write-Host "-> Copy the section above into your chat with Claude." -ForegroundColor Cyan

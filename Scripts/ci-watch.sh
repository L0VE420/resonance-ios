#!/usr/bin/env bash
# Trigger the Resonance GitHub Actions build, poll until done, and dump
# logs on failure. Works on macOS, Linux, and Git Bash on Windows.
#
#   ./Scripts/ci-watch.sh                  # adhoc + watch
#   ./Scripts/ci-watch.sh --download       # download the IPA on success
#   ./Scripts/ci-watch.sh -s development   # development-signed IPA
#   ./Scripts/ci-watch.sh -w simulator-ipa.yml
#
# Requires: gh CLI authenticated (`gh auth login`, scopes: repo, workflow).

set -euo pipefail

WORKFLOW="sideload-ipa.yml"
SIGNING="adhoc"
DOWNLOAD=0
DL_PATH="build/ci-artifacts"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--workflow)   WORKFLOW="$2"; shift 2 ;;
        -s|--signing)    SIGNING="$2";  shift 2 ;;
        --download)      DOWNLOAD=1;    shift   ;;
        --path)          DL_PATH="$2";  shift 2 ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

[[ "$SIGNING" == "ad-hoc" ]] && SIGNING="adhoc"

# --- preflight ----------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
    echo "✗ gh CLI not found. Install from https://cli.github.com" >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh is not authenticated. Run: gh auth login" >&2
    exit 2
fi

# --- trigger ------------------------------------------------------------
echo "▶ Triggering workflow '$WORKFLOW' (signing=$SIGNING) on branch $BRANCH"
gh workflow run "$WORKFLOW" --ref "$BRANCH" -f "signing=$SIGNING" >/dev/null

# gh workflow run exits immediately; wait for the run to register then
# pick the latest matching run.
sleep 5
RUN_ID="$(gh run list --workflow "$WORKFLOW" --limit 1 --json databaseId -q '.[0].databaseId')"
[[ -z "$RUN_ID" ]] && { echo "✗ no run found after trigger" >&2; exit 3; }
RUN_URL="$(gh run view "$RUN_ID" --json url -q .url)"
echo "▶ Run URL: $RUN_URL"

# --- watch --------------------------------------------------------------
echo "▶ Watching run $RUN_ID …"
while :; do
    STATUS="$(gh run view "$RUN_ID" --json status -q .status)"
    case "$STATUS" in
        completed) break ;;
        in_progress|queued|waiting|pending)
            printf "  · %-12s — waiting 15 s\n" "$STATUS"
            sleep 15 ;;
        *)
            printf "  · %-12s — waiting 15 s\n" "$STATUS"
            sleep 15 ;;
    esac
done

CONCLUSION="$(gh run view "$RUN_ID" --json conclusion -q .conclusion)"
if [[ "$CONCLUSION" == "success" ]]; then
    echo "✓ Run succeeded"
    if [[ "$DOWNLOAD" -eq 1 ]]; then
        mkdir -p "$DL_PATH"
        echo "▶ Downloading artifacts to $DL_PATH"
        gh run download "$RUN_ID" --dir "$DL_PATH"
        # Surface any IPA we found.
        find "$DL_PATH" -name '*.ipa' -type f 2>/dev/null | while read -r p; do
            echo "  ✓ IPA: $p"
        done
    fi
    exit 0
fi

echo ""
echo "=== Failure summary ==="
echo ""

echo "▶ Steps:"
gh run view "$RUN_ID" --json jobs,name,conclusion,steps \
    --jq '.jobs[] | "  [\(.conclusion)] \(.name)"' 2>/dev/null || true

echo ""
echo "▶ Failed-step logs (most recent 250 lines each):"

# Pull each failed job's log tail via the API.
gh api "runs/$RUN_ID/jobs" --jq '.jobs[] | select(.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out") | .databaseId' 2>/dev/null \
| while read -r JOB_ID; do
    [[ -z "$JOB_ID" ]] && continue
    echo ""
    echo "----- job $JOB_ID -----"
    gh run view "$RUN_ID" --job "$JOB_ID" --log 2>&1 | tail -n 250
done

echo ""
echo "→ Paste the output above (or just the failing step's tail)"
echo "  back to Claude to start the auto-fix loop."
exit 10

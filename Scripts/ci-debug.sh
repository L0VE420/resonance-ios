#!/usr/bin/env bash
# Print the failure log of the most recent failed Resonance build.
#
#   ./Scripts/ci-debug.sh                  # last failed run of sideload-ipa.yml
#   ./Scripts/ci-debug.sh -w ipa.yml -r 1234567890

set -euo pipefail

WORKFLOW="sideload-ipa.yml"
RUN_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--workflow) WORKFLOW="$2"; shift 2 ;;
        -r|--run-id)   RUN_ID="$2";   shift 2 ;;
        -h|--help)
            sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

if ! command -v gh >/dev/null 2>&1; then
    echo "✗ gh not found" >&2; exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh not authenticated" >&2; exit 2
fi

if [[ -z "$RUN_ID" ]]; then
    RUN_ID="$(gh run list --workflow "$WORKFLOW" --limit 20 \
        --json databaseId,conclusion,displayTitle,headBranch,url \
        -q '.[] | select(.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out") | .databaseId' \
        | head -n1)"
    if [[ -z "$RUN_ID" ]]; then
        echo "No failed runs in the last 20 for $WORKFLOW" >&2
        exit 0
    fi
    echo "▶ Latest failed run: $RUN_ID"
fi

echo ""
echo "=== Steps ==="
gh run view "$RUN_ID" --json jobs,name,conclusion,steps \
    --jq '.jobs[] | "  [\(.conclusion)] \(.name)"' 2>/dev/null || true

echo ""
echo "=== Failed-step logs ==="
gh api "runs/$RUN_ID/jobs" --jq '.jobs[] | select(.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out") | .databaseId' 2>/dev/null \
| while read -r JOB_ID; do
    [[ -z "$JOB_ID" ]] && continue
    echo ""
    echo "----- job $JOB_ID -----"
    gh run view "$RUN_ID" --job "$JOB_ID" --log 2>&1 | tail -n 250
done

echo ""
echo "→ Copy the section above into your chat with Claude."

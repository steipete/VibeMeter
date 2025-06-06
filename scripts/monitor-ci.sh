#!/bin/bash
set -euo pipefail

# CI Monitoring Script for VibeMeter
# Usage: ./scripts/monitor-ci.sh [options]
# Options:
#   --watch       : Continuously monitor (refresh every 30s)
#   --pr <number> : Monitor specific PR
#   --branch <name>: Monitor specific branch

WATCH_MODE=false
PR_NUMBER=""
BRANCH_NAME=""
REPO="steipete/VibeMeter"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --pr)
            PR_NUMBER="$2"
            shift 2
            ;;
        --branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function print_status() {
    local status=$1
    case $status in
        "completed")
            echo -ne "${GREEN}✓${NC}"
            ;;
        "in_progress")
            echo -ne "${YELLOW}⏳${NC}"
            ;;
        "queued")
            echo -ne "${BLUE}⏸${NC}"
            ;;
        *)
            echo -ne "${RED}✗${NC}"
            ;;
    esac
}

function print_conclusion() {
    local conclusion=$1
    case $conclusion in
        "success")
            echo -ne "${GREEN}SUCCESS${NC}"
            ;;
        "failure")
            echo -ne "${RED}FAILURE${NC}"
            ;;
        "cancelled")
            echo -ne "${YELLOW}CANCELLED${NC}"
            ;;
        *)
            echo -ne "-"
            ;;
    esac
}

function monitor_runs() {
    clear
    echo -e "${BLUE}🔍 VibeMeter CI Monitor${NC}"
    echo -e "Repository: $REPO"
    date
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get workflow runs
    local filter=""
    if [[ -n "$PR_NUMBER" ]]; then
        filter="--jq '.workflow_runs[] | select(.pull_requests[].number == $PR_NUMBER)'"
    elif [[ -n "$BRANCH_NAME" ]]; then
        filter="--branch $BRANCH_NAME"
    fi
    
    # List recent runs
    echo -e "\n${YELLOW}Recent Workflow Runs:${NC}"
    printf "%-4s %-10s %-30s %-20s %-10s %-15s\n" "ST" "RESULT" "WORKFLOW" "BRANCH" "DURATION" "STARTED"
    echo -e "────────────────────────────────────────────────────────────────────────────────"
    
    gh run list --repo=$REPO --limit=10 --json status,conclusion,name,headBranch,displayTitle,createdAt,event,workflowName,databaseId |
    jq -r '.[] | [.status, .conclusion, .workflowName, .headBranch, .createdAt, .databaseId] | @tsv' |
    while IFS=$'\t' read -r status conclusion workflow branch created_at run_id; do
        # Format timestamp
        created_formatted=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" "+%m/%d %H:%M" 2>/dev/null || echo "$created_at")
        
        # Get duration if completed
        if [[ "$status" == "completed" ]]; then
            duration=$(gh run view $run_id --repo=$REPO --json jobs --jq '[.jobs[].completedAt, .jobs[].startedAt] | select(.[0] != null and .[1] != null) | (.[0] | fromdateiso8601) - (.[1] | fromdateiso8601) | . / 60 | floor' 2>/dev/null | head -1 || echo "-")
            if [[ -n "$duration" && "$duration" != "-" ]]; then
                duration="${duration}m"
            else
                duration="-"
            fi
        else
            duration="running"
        fi
        
        # Truncate long names
        workflow=$(echo "$workflow" | cut -c1-30)
        branch=$(echo "$branch" | cut -c1-20)
        
        # Print row
        print_status "$status"
        echo -n "   "
        printf "%-10s %-30s %-20s %-10s %-15s\n" \
            "$(print_conclusion "$conclusion")" \
            "$workflow" \
            "$branch" \
            "$duration" \
            "$created_formatted"
    done
    
    # Show active/running workflows
    echo -e "\n${YELLOW}Active Jobs:${NC}"
    gh run list --repo=$REPO --status=in_progress --json databaseId,workflowName,jobs --jq '.[] | .databaseId as $id | .workflowName as $wf | .jobs[] | select(.status == "in_progress") | [$id, $wf, .name] | @tsv' |
    while IFS=$'\t' read -r run_id workflow job_name; do
        echo -e "  ${YELLOW}⏳${NC} [$workflow] $job_name (Run #$run_id)"
    done || echo "  None"
    
    # Show recent failures
    echo -e "\n${YELLOW}Recent Failures:${NC}"
    gh run list --repo=$REPO --status=completed --workflow=all --limit=20 --json conclusion,workflowName,event,headBranch,displayTitle,databaseId |
    jq -r '.[] | select(.conclusion == "failure") | [.workflowName, .headBranch, .displayTitle, .databaseId] | @tsv' |
    head -5 |
    while IFS=$'\t' read -r workflow branch title run_id; do
        echo -e "  ${RED}✗${NC} [$workflow] $title"
        echo -e "     Branch: $branch | Run: $run_id"
        echo -e "     View: gh run view $run_id --repo=$REPO"
    done || echo "  None"
    
    # Summary statistics
    echo -e "\n${YELLOW}24-Hour Summary:${NC}"
    local total=$(gh run list --repo=$REPO --limit=50 --json conclusion | jq -r 'length')
    local success=$(gh run list --repo=$REPO --limit=50 --json conclusion | jq -r '[.[] | select(.conclusion == "success")] | length')
    local failure=$(gh run list --repo=$REPO --limit=50 --json conclusion | jq -r '[.[] | select(.conclusion == "failure")] | length')
    local success_rate=0
    if [[ $total -gt 0 ]]; then
        success_rate=$((success * 100 / total))
    fi
    
    echo -e "  Total Runs: $total"
    echo -e "  Success: ${GREEN}$success${NC} | Failure: ${RED}$failure${NC}"
    echo -e "  Success Rate: $success_rate%"
}

# Main loop
if [[ "$WATCH_MODE" == "true" ]]; then
    echo -e "${BLUE}Starting CI monitor in watch mode. Press Ctrl+C to exit.${NC}"
    while true; do
        monitor_runs
        sleep 30
    done
else
    monitor_runs
fi
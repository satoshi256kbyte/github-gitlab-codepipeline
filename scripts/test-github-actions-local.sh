#!/bin/bash

# GitHub Actions local testing script using act

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKFLOW_FILE=".github/workflows/ci-local.yml"
JOB=""
DRY_RUN=false
LIST_JOBS=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  -w, --workflow FILE    Workflow file (default: $WORKFLOW_FILE)"
    echo "  -j, --job JOB         Run specific job only"
    echo "  -d, --dry-run         Show execution plan"
    echo "  -l, --list            List available jobs"
    echo "  -h, --help            Show help"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--workflow) WORKFLOW_FILE="$2"; shift 2 ;;
        -j|--job) JOB="$2"; shift 2 ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        -l|--list) LIST_JOBS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if ! command -v act &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} act not installed. Run: brew install act"
    exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

if [ "$LIST_JOBS" = true ]; then
    act -W "$WORKFLOW_FILE" --list
    exit 0
fi

ACT_CMD="act -W $WORKFLOW_FILE --env-file .env.localstack --container-architecture linux/amd64"

if [ -n "$JOB" ]; then
    ACT_CMD="$ACT_CMD -j $JOB"
fi

if [ "$DRY_RUN" = true ]; then
    ACT_CMD="$ACT_CMD --dryrun"
fi

echo -e "${BLUE}[INFO]${NC} Running: $ACT_CMD"

if eval $ACT_CMD; then
    echo -e "${GREEN}[SUCCESS]${NC} GitHub Actions local test completed"
else
    echo -e "${RED}[ERROR]${NC} GitHub Actions local test failed"
    exit 1
fi

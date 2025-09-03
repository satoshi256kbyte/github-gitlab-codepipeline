#!/bin/bash

# Local Test Runner Script
# This script runs tests in the local environment with proper environment variables set

set -e

# Set local environment variables
export ENVIRONMENT=local
export STAGE_NAME=local
export SKIP_REAL_AWS_SERVICES=true
export AWS_DEFAULT_REGION=ap-northeast-1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running tests in local environment...${NC}"
echo "Environment variables set:"
echo "  ENVIRONMENT=$ENVIRONMENT"
echo "  STAGE_NAME=$STAGE_NAME"
echo "  SKIP_REAL_AWS_SERVICES=$SKIP_REAL_AWS_SERVICES"
echo "  AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
echo ""

# Run tests with the specified arguments or default to all tests
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Running all tests with coverage and JUnit XML...${NC}"
    uv run pytest modules/api/tests/ -v --tb=short --cov=modules/api --cov-report=xml --cov-report=html --junit-xml=test-results.xml
else
    echo -e "${YELLOW}Running tests with arguments: $@${NC}"
    uv run pytest "$@"
fi

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    if [ -f "test-results.xml" ]; then
        echo -e "${GREEN}📊 JUnit XML report: test-results.xml${NC}"
    fi
    if [ -f "coverage.xml" ]; then
        echo -e "${GREEN}📈 Coverage XML report: coverage.xml${NC}"
    fi
    if [ -d "htmlcov" ]; then
        echo -e "${GREEN}🌐 HTML coverage report: htmlcov/index.html${NC}"
    fi
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    exit 1
fi

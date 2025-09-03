#!/bin/bash

# Local CI/CD Integration Test Script
# This script tests all three CI/CD tools (GitHub Actions, GitLab CI/CD, CodePipeline) locally
# using act, gitlab-ci-local, and LocalStack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCALSTACK_ENDPOINT="http://localhost:4566"
TIMEOUT=300  # 5 minutes timeout for each test

# Test results
GITHUB_ACTIONS_RESULT=""
GITLAB_CI_RESULT=""
CODEPIPELINE_RESULT=""

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        missing_tools+=("docker-compose")
    fi
    
    # Check act (optional)
    if ! command -v act >/dev/null 2>&1; then
        log_warning "act is not installed. GitHub Actions local testing will be skipped."
    fi
    
    # Check gitlab-ci-local (optional)
    if ! command -v gitlab-ci-local >/dev/null 2>&1; then
        log_warning "gitlab-ci-local is not installed. GitLab CI/CD local testing will be skipped."
    fi
    
    # Check AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        missing_tools+=("aws")
    fi
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Start LocalStack
start_localstack() {
    log_info "Starting LocalStack..."
    
    cd "$PROJECT_ROOT"
    
    # Check if LocalStack is already running
    if curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null 2>&1; then
        log_info "LocalStack is already running"
    else
        log_info "Starting LocalStack services..."
        make -f Makefile.localstack localstack-start
        
        # Wait for LocalStack to be ready
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null 2>&1; then
                log_success "LocalStack is ready"
                break
            fi
            
            log_info "Waiting for LocalStack... (attempt $((attempts + 1))/$max_attempts)"
            sleep 2
            ((attempts++))
        done
        
        if [ $attempts -eq $max_attempts ]; then
            log_error "LocalStack failed to start within timeout"
            exit 1
        fi
    fi
    
    # Initialize LocalStack resources
    log_info "Initializing LocalStack resources..."
    make -f Makefile.localstack localstack-init
}

# Test GitHub Actions with act
test_github_actions() {
    log_info "Testing GitHub Actions with act..."
    
    if ! command -v act >/dev/null 2>&1; then
        log_warning "act is not installed. Skipping GitHub Actions test."
        GITHUB_ACTIONS_RESULT="SKIPPED"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Set environment variables for local testing
    export STAGE_NAME=local
    export SKIP_REAL_AWS_SERVICES=true
    export SKIP_CODEGURU_SECURITY=true
    export SKIP_CODEQL=true
    export SKIP_DEPENDABOT=true
    export LOCALSTACK_ENDPOINT="$LOCALSTACK_ENDPOINT"
    
    log_info "Running GitHub Actions workflow with act..."
    
    # Run specific jobs that can work locally
    local jobs=("lint" "test")
    local failed_jobs=()
    
    for job in "${jobs[@]}"; do
        log_info "Running job: $job"
        
        if gtimeout $TIMEOUT act -j "$job" --env-file .env.localstack --verbose 2>/dev/null || act -j "$job" --env-file .env.localstack --verbose; then
            log_success "GitHub Actions job '$job' completed successfully"
        else
            log_error "GitHub Actions job '$job' failed"
            failed_jobs+=("$job")
        fi
    done
    
    if [ ${#failed_jobs[@]} -eq 0 ]; then
        GITHUB_ACTIONS_RESULT="PASSED"
        log_success "GitHub Actions local test completed successfully"
    else
        GITHUB_ACTIONS_RESULT="FAILED (${failed_jobs[*]})"
        log_error "GitHub Actions local test failed for jobs: ${failed_jobs[*]}"
    fi
}

# Test GitLab CI/CD with gitlab-ci-local
test_gitlab_ci() {
    log_info "Testing GitLab CI/CD with gitlab-ci-local..."
    
    if ! command -v gitlab-ci-local >/dev/null 2>&1; then
        log_warning "gitlab-ci-local is not installed. Skipping GitLab CI/CD test."
        GITLAB_CI_RESULT="SKIPPED"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Set environment variables for local testing
    export STAGE_NAME=local
    export IS_LOCAL_ENV=true
    export SKIP_REAL_AWS_SERVICES=true
    export SKIP_CODEGURU_SECURITY=true
    export LOCALSTACK_ENDPOINT="$LOCALSTACK_ENDPOINT"
    
    log_info "Running GitLab CI/CD pipeline with gitlab-ci-local..."
    
    # Run specific stages that can work locally
    local stages=("cache" "check")
    local failed_stages=()
    
    for stage in "${stages[@]}"; do
        log_info "Running stage: $stage"
        
        if gtimeout $TIMEOUT gitlab-ci-local --stage "$stage" --env-file .env.localstack 2>/dev/null || gitlab-ci-local --stage "$stage" --env-file .env.localstack; then
            log_success "GitLab CI/CD stage '$stage' completed successfully"
        else
            log_error "GitLab CI/CD stage '$stage' failed"
            failed_stages+=("$stage")
        fi
    done
    
    if [ ${#failed_stages[@]} -eq 0 ]; then
        GITLAB_CI_RESULT="PASSED"
        log_success "GitLab CI/CD local test completed successfully"
    else
        GITLAB_CI_RESULT="FAILED (${failed_stages[*]})"
        log_error "GitLab CI/CD local test failed for stages: ${failed_stages[*]}"
    fi
}

# Test CodePipeline buildspecs locally
test_codepipeline_buildspecs() {
    log_info "Testing CodePipeline buildspecs locally..."
    
    cd "$PROJECT_ROOT"
    
    # Set environment variables for local testing
    export STAGE_NAME=local
    export SERVICE_NAME=cicd-comparison
    export AWS_DEFAULT_REGION=ap-northeast-1
    export AWS_ENDPOINT_URL="$LOCALSTACK_ENDPOINT"
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    
    # Source common environment
    source cicd/buildspecs/common_env.sh
    
    log_info "Testing CodePipeline buildspec phases..."
    
    local buildspecs=("cache" "lint" "test" "sca" "sast")
    local failed_buildspecs=()
    
    for buildspec in "${buildspecs[@]}"; do
        log_info "Testing buildspec: $buildspec"
        
        local buildspec_file="cicd/buildspecs/${buildspec}.yml"
        
        if [ ! -f "$buildspec_file" ]; then
            log_warning "Buildspec file not found: $buildspec_file"
            continue
        fi
        
        # Simulate CodeBuild phases
        log_info "Simulating install phase for $buildspec..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if bash cicd/buildspecs/common_install_macos.sh; then
                log_success "Install phase completed for $buildspec"
            else
                log_error "Install phase failed for $buildspec"
                failed_buildspecs+=("$buildspec")
                continue
            fi
        elif bash cicd/buildspecs/common_install.sh; then
            log_success "Install phase completed for $buildspec"
        else
            log_error "Install phase failed for $buildspec"
            failed_buildspecs+=("$buildspec")
            continue
        fi
        
        log_info "Simulating pre_build phase for $buildspec..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if bash cicd/buildspecs/common_pre_build_macos.sh; then
                log_success "Pre_build phase completed for $buildspec"
            else
                log_error "Pre_build phase failed for $buildspec"
                failed_buildspecs+=("$buildspec")
                continue
            fi
        elif bash cicd/buildspecs/common_pre_build.sh; then
            log_success "Pre_build phase completed for $buildspec"
        else
            log_error "Pre_build phase failed for $buildspec"
            failed_buildspecs+=("$buildspec")
            continue
        fi
        
        # For specific buildspecs, run their build commands
        case $buildspec in
            "lint")
                log_info "Running lint commands..."
                if uv run ruff check . && uv run ruff format --check .; then
                    log_success "Lint buildspec completed successfully"
                else
                    log_error "Lint buildspec failed"
                    failed_buildspecs+=("$buildspec")
                fi
                ;;
            "test")
                log_info "Running test commands..."
                if uv run pytest modules/api/tests/ -v; then
                    log_success "Test buildspec completed successfully"
                else
                    log_error "Test buildspec failed"
                    failed_buildspecs+=("$buildspec")
                fi
                ;;
            "sca"|"sast")
                log_info "Simulating $buildspec commands (skipped in local environment)..."
                log_success "$buildspec buildspec completed (skipped for local)"
                ;;
        esac
    done
    
    if [ ${#failed_buildspecs[@]} -eq 0 ]; then
        CODEPIPELINE_RESULT="PASSED"
        log_success "CodePipeline buildspecs local test completed successfully"
    else
        CODEPIPELINE_RESULT="FAILED (${failed_buildspecs[*]})"
        log_error "CodePipeline buildspecs local test failed for: ${failed_buildspecs[*]}"
    fi
}

# Test LocalStack connectivity
test_localstack_connectivity() {
    log_info "Testing LocalStack connectivity..."
    
    # Source LocalStack helpers
    source "$PROJECT_ROOT/scripts/localstack-helpers.sh"
    setup_localstack_env
    
    log_info "Testing AWS services in LocalStack..."
    
    # Test S3
    if aws --endpoint-url=$LOCALSTACK_ENDPOINT s3 ls >/dev/null 2>&1; then
        log_success "S3 service is accessible"
    else
        log_error "S3 service is not accessible"
        return 1
    fi
    
    # Test Lambda
    if aws --endpoint-url=$LOCALSTACK_ENDPOINT lambda list-functions --region $AWS_DEFAULT_REGION >/dev/null 2>&1; then
        log_success "Lambda service is accessible"
    else
        log_error "Lambda service is not accessible"
        return 1
    fi
    
    # Test CloudWatch Logs
    if aws --endpoint-url=$LOCALSTACK_ENDPOINT logs describe-log-groups --region $AWS_DEFAULT_REGION >/dev/null 2>&1; then
        log_success "CloudWatch Logs service is accessible"
    else
        log_error "CloudWatch Logs service is not accessible"
        return 1
    fi
    
    log_success "LocalStack connectivity test completed successfully"
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    local report_file="$PROJECT_ROOT/local-test-report.md"
    
    cat > "$report_file" << EOF
# Local CI/CD Integration Test Report

Generated on: $(date)

## Test Results Summary

| CI/CD Tool | Status | Details |
|------------|--------|---------|
| GitHub Actions | $GITHUB_ACTIONS_RESULT | act-based local testing |
| GitLab CI/CD | $GITLAB_CI_RESULT | gitlab-ci-local-based testing |
| CodePipeline | $CODEPIPELINE_RESULT | buildspec simulation |

## Environment Information

- LocalStack Endpoint: $LOCALSTACK_ENDPOINT
- Test Environment: local
- Project Root: $PROJECT_ROOT

## LocalStack Services Status

$(curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" | jq '.' 2>/dev/null || echo "LocalStack health check failed")

## Recommendations

### For GitHub Actions:
- Install \`act\` for local GitHub Actions testing
- Use \`.env.localstack\` for environment variables
- Some GitHub-specific features (CodeQL, Dependabot) will be skipped locally

### For GitLab CI/CD:
- Install \`gitlab-ci-local\` for local GitLab CI/CD testing
- GitLab SAST and Dependency Scanning can run locally
- AWS CodeGuru Security will be skipped in local environment

### For CodePipeline:
- Use LocalStack for AWS service simulation
- CodeGuru Security and Inspector will be skipped locally
- Buildspec phases can be tested individually

## Next Steps

1. Fix any failed tests before deploying to real environments
2. Test with real AWS services in dev/staging environments
3. Monitor CI/CD pipeline performance differences between tools

EOF

    log_success "Test report generated: $report_file"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    
    # Stop LocalStack if we started it
    if [ "$LOCALSTACK_STARTED" = "true" ]; then
        log_info "Stopping LocalStack..."
        cd "$PROJECT_ROOT"
        make -f Makefile.localstack localstack-stop
    fi
}

# Main execution
main() {
    log_info "Starting Local CI/CD Integration Test..."
    log_info "Project Root: $PROJECT_ROOT"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Start LocalStack
    start_localstack
    LOCALSTACK_STARTED=true
    
    # Test LocalStack connectivity
    test_localstack_connectivity
    
    # Run CI/CD tool tests
    test_github_actions
    test_gitlab_ci
    test_codepipeline_buildspecs
    
    # Generate report
    generate_report
    
    # Summary
    log_info "=== Test Summary ==="
    log_info "GitHub Actions: $GITHUB_ACTIONS_RESULT"
    log_info "GitLab CI/CD: $GITLAB_CI_RESULT"
    log_info "CodePipeline: $CODEPIPELINE_RESULT"
    
    # Determine overall result
    local overall_result="PASSED"
    if [[ "$GITHUB_ACTIONS_RESULT" == FAILED* ]] || [[ "$GITLAB_CI_RESULT" == FAILED* ]] || [[ "$CODEPIPELINE_RESULT" == FAILED* ]]; then
        overall_result="FAILED"
    fi
    
    if [ "$overall_result" = "PASSED" ]; then
        log_success "Local CI/CD Integration Test completed successfully!"
        exit 0
    else
        log_error "Local CI/CD Integration Test completed with failures!"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Local CI/CD Integration Test Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    --github-only       Test only GitHub Actions
    --gitlab-only       Test only GitLab CI/CD
    --codepipeline-only Test only CodePipeline buildspecs
    --no-localstack     Skip LocalStack startup (assume it's already running)

EXAMPLES:
    $0                  # Run all tests
    $0 --github-only    # Test only GitHub Actions
    $0 --no-localstack  # Run tests without starting LocalStack

PREREQUISITES:
    - Docker and Docker Compose
    - AWS CLI
    - jq
    - act (optional, for GitHub Actions testing)
    - gitlab-ci-local (optional, for GitLab CI/CD testing)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --github-only)
            GITHUB_ONLY=true
            shift
            ;;
        --gitlab-only)
            GITLAB_ONLY=true
            shift
            ;;
        --codepipeline-only)
            CODEPIPELINE_ONLY=true
            shift
            ;;
        --no-localstack)
            NO_LOCALSTACK=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
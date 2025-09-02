#!/bin/bash

# GitLab CI/CD Local Test Script using gitlab-ci-local
# This script tests GitLab CI/CD pipelines locally

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

# Check if gitlab-ci-local is installed
check_gitlab_ci_local() {
    if ! command -v gitlab-ci-local >/dev/null 2>&1; then
        log_error "gitlab-ci-local is not installed. Please install gitlab-ci-local to run GitLab CI/CD locally."
        log_info "Installation instructions: https://github.com/firecow/gitlab-ci-local#installation"
        exit 1
    fi
    
    log_success "gitlab-ci-local is installed: $(gitlab-ci-local --version)"
}

# Setup environment for local testing
setup_environment() {
    log_info "Setting up environment for local GitLab CI/CD testing..."
    
    cd "$PROJECT_ROOT"
    
    # Create .env.localstack if it doesn't exist
    if [ ! -f .env.localstack ]; then
        log_warning ".env.localstack not found. Creating default configuration..."
        cat > .env.localstack << EOF
# LocalStack Environment Configuration for GitLab CI/CD
LOCALSTACK_ENDPOINT=http://localhost:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=ap-northeast-1
AWS_ENDPOINT_URL=http://localhost:4566

# Environment Settings
ENVIRONMENT=local
STAGE_NAME=local
SERVICE_NAME=cicd-comparison
CICD_TOOL=gitlab

# GitLab CI/CD specific
CI_COMMIT_REF_NAME=local
CI_PIPELINE_SOURCE=gitlab-ci-local
IS_LOCAL_ENV=true

# Skip flags for local environment
SKIP_REAL_AWS_SERVICES=true
SKIP_CODEGURU_SECURITY=true
SKIP_GITLAB_SAST=false
SKIP_GITLAB_DEPENDENCY_SCANNING=false

# Local ports
GITLAB_LOCAL_PORT=8081
EOF
    fi
    
    # Create gitlab-ci-local configuration if it doesn't exist
    if [ ! -f .gitlab-ci-local.yml ]; then
        log_info "Creating .gitlab-ci-local.yml configuration..."
        cat > .gitlab-ci-local.yml << EOF
# gitlab-ci-local configuration
variables:
  STAGE_NAME: local
  IS_LOCAL_ENV: "true"
  SKIP_REAL_AWS_SERVICES: "true"
  SKIP_CODEGURU_SECURITY: "true"
  CI_COMMIT_REF_NAME: local
  CI_PIPELINE_SOURCE: gitlab-ci-local

# Use local Docker images when possible
image: ubuntu:22.04

# Enable shell executor for better local testing
shell-executor:
  enable: true
EOF
    fi
    
    log_success "Environment setup completed"
}

# Test specific GitLab CI/CD stages
test_gitlab_ci_stages() {
    log_info "Testing GitLab CI/CD stages locally..."
    
    cd "$PROJECT_ROOT"
    
    # Stages that can be tested locally
    local stages=("cache" "check")
    local failed_stages=()
    
    for stage in "${stages[@]}"; do
        log_info "Testing stage: $stage"
        
        if gitlab-ci-local --stage "$stage" --env-file .env.localstack; then
            log_success "Stage '$stage' completed successfully"
        else
            log_error "Stage '$stage' failed"
            failed_stages+=("$stage")
        fi
    done
    
    # Test deploy stage (should work with LocalStack)
    log_info "Testing deploy stage (with LocalStack simulation)..."
    if gitlab-ci-local --stage deploy --env-file .env.localstack; then
        log_success "Deploy stage completed (LocalStack simulation)"
    else
        log_warning "Deploy stage failed (expected without real AWS resources)"
    fi
    
    if [ ${#failed_stages[@]} -eq 0 ]; then
        log_success "All testable GitLab CI/CD stages completed successfully"
        return 0
    else
        log_error "Failed stages: ${failed_stages[*]}"
        return 1
    fi
}

# Test specific GitLab CI/CD jobs
test_gitlab_ci_jobs() {
    log_info "Testing specific GitLab CI/CD jobs..."
    
    cd "$PROJECT_ROOT"
    
    # Jobs that can be tested locally
    local jobs=("cache_dependencies" "lint" "test" "sca_check" "sast_check")
    local failed_jobs=()
    
    for job in "${jobs[@]}"; do
        log_info "Testing job: $job"
        
        if gitlab-ci-local --job "$job" --env-file .env.localstack; then
            log_success "Job '$job' completed successfully"
        else
            log_error "Job '$job' failed"
            failed_jobs+=("$job")
        fi
    done
    
    if [ ${#failed_jobs[@]} -eq 0 ]; then
        log_success "All testable GitLab CI/CD jobs completed successfully"
        return 0
    else
        log_error "Failed jobs: ${failed_jobs[*]}"
        return 1
    fi
}

# Validate GitLab CI/CD configuration
validate_gitlab_ci() {
    log_info "Validating GitLab CI/CD configuration..."
    
    cd "$PROJECT_ROOT"
    
    if gitlab-ci-local --list; then
        log_success "GitLab CI/CD configuration is valid"
        return 0
    else
        log_error "GitLab CI/CD configuration validation failed"
        return 1
    fi
}

# List available jobs and stages
list_jobs_and_stages() {
    log_info "Available GitLab CI/CD jobs and stages:"
    
    cd "$PROJECT_ROOT"
    
    if gitlab-ci-local --list; then
        log_success "Job and stage listing completed"
    else
        log_error "Failed to list jobs and stages"
    fi
}

# Show help
show_help() {
    cat << EOF
GitLab CI/CD Local Test Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -l, --list          List available jobs and stages
    -j, --job JOB       Test specific job
    -s, --stage STAGE   Test specific stage
    --validate          Validate GitLab CI/CD configuration only
    --setup-only        Only setup environment, don't run tests

EXAMPLES:
    $0                  # Run all testable stages
    $0 -j lint          # Test only lint job
    $0 -s check         # Test check stage
    $0 --validate       # Validate configuration
    $0 --list           # List available jobs and stages

PREREQUISITES:
    - gitlab-ci-local (https://github.com/firecow/gitlab-ci-local)
    - Docker
    - LocalStack (optional, for AWS service simulation)

EOF
}

# Main execution
main() {
    local specific_job=""
    local specific_stage=""
    local validate_only=false
    local setup_only=false
    local list_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            -j|--job)
                specific_job="$2"
                shift 2
                ;;
            -s|--stage)
                specific_stage="$2"
                shift 2
                ;;
            --validate)
                validate_only=true
                shift
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "Starting GitLab CI/CD local testing..."
    
    # Check prerequisites
    check_gitlab_ci_local
    
    # Setup environment
    setup_environment
    
    if [ "$list_only" = true ]; then
        list_jobs_and_stages
        exit 0
    fi
    
    if [ "$validate_only" = true ]; then
        validate_gitlab_ci
        exit $?
    fi
    
    if [ "$setup_only" = true ]; then
        log_success "Environment setup completed. You can now run gitlab-ci-local commands manually."
        exit 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Validate configuration first
    if ! validate_gitlab_ci; then
        log_error "GitLab CI/CD configuration validation failed. Please fix the configuration."
        exit 1
    fi
    
    # Run specific job or stage
    if [ -n "$specific_job" ]; then
        log_info "Testing specific job: $specific_job"
        if gitlab-ci-local --job "$specific_job" --env-file .env.localstack; then
            log_success "Job '$specific_job' completed successfully"
        else
            log_error "Job '$specific_job' failed"
            exit 1
        fi
    elif [ -n "$specific_stage" ]; then
        log_info "Testing specific stage: $specific_stage"
        if gitlab-ci-local --stage "$specific_stage" --env-file .env.localstack; then
            log_success "Stage '$specific_stage' completed successfully"
        else
            log_error "Stage '$specific_stage' failed"
            exit 1
        fi
    else
        # Run all testable stages
        test_gitlab_ci_stages
    fi
    
    log_success "GitLab CI/CD local testing completed!"
}

# Run main function
main "$@"
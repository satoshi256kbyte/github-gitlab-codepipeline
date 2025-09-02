#!/bin/bash

# CodePipeline Local Test Script
# This script tests CodePipeline buildspecs locally using LocalStack

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for CodePipeline local testing..."
    
    local missing_tools=()
    
    # Check AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        missing_tools+=("aws")
    fi
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Setup environment for local testing
setup_environment() {
    log_info "Setting up environment for CodePipeline local testing..."
    
    cd "$PROJECT_ROOT"
    
    # Set environment variables for local testing
    export STAGE_NAME=local
    export SERVICE_NAME=cicd-comparison
    export AWS_DEFAULT_REGION=ap-northeast-1
    export AWS_ENDPOINT_URL="$LOCALSTACK_ENDPOINT"
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    
    # Source common environment
    if [ -f codepipeline/buildspecs/common_env.sh ]; then
        source codepipeline/buildspecs/common_env.sh
        log_success "Common environment variables loaded"
    else
        log_warning "common_env.sh not found, using default values"
    fi
    
    log_success "Environment setup completed"
}

# Test buildspec phases
test_buildspec_phases() {
    local buildspec_name=$1
    local buildspec_file="codepipeline/buildspecs/${buildspec_name}.yml"
    
    if [ ! -f "$buildspec_file" ]; then
        log_error "Buildspec file not found: $buildspec_file"
        return 1
    fi
    
    log_info "Testing buildspec: $buildspec_name"
    
    # Install phase
    log_info "Running install phase for $buildspec_name..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if bash codepipeline/buildspecs/common_install_macos.sh; then
            log_success "Install phase completed for $buildspec_name"
        else
            log_error "Install phase failed for $buildspec_name"
            return 1
        fi
    elif bash codepipeline/buildspecs/common_install.sh; then
        log_success "Install phase completed for $buildspec_name"
    else
        log_error "Install phase failed for $buildspec_name"
        return 1
    fi
    
    # Pre-build phase
    log_info "Running pre_build phase for $buildspec_name..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if bash codepipeline/buildspecs/common_pre_build_macos.sh; then
            log_success "Pre_build phase completed for $buildspec_name"
        else
            log_error "Pre_build phase failed for $buildspec_name"
            return 1
        fi
    elif bash codepipeline/buildspecs/common_pre_build.sh; then
        log_success "Pre_build phase completed for $buildspec_name"
    else
        log_error "Pre_build phase failed for $buildspec_name"
        return 1
    fi
    
    # Build phase (specific to each buildspec)
    log_info "Running build phase for $buildspec_name..."
    case $buildspec_name in
        "cache")
            test_cache_buildspec
            ;;
        "lint")
            test_lint_buildspec
            ;;
        "test")
            test_test_buildspec
            ;;
        "sca")
            test_sca_buildspec
            ;;
        "sast")
            test_sast_buildspec
            ;;
        "deploy_lambda")
            test_deploy_lambda_buildspec
            ;;
        "deploy-ecs")
            test_deploy_ecs_buildspec
            ;;
        "deploy_ec2")
            test_deploy_ec2_buildspec
            ;;
        *)
            log_warning "Unknown buildspec: $buildspec_name"
            return 1
            ;;
    esac
}

# Test cache buildspec
test_cache_buildspec() {
    log_info "Testing cache buildspec build phase..."
    
    # Simulate cache creation
    if uv export --all-packages --no-dev --frozen --no-editable -o requirements.txt --no-emit-workspace --no-hashes --no-header; then
        log_success "Cache buildspec build phase completed"
        return 0
    else
        log_error "Cache buildspec build phase failed"
        return 1
    fi
}

# Test lint buildspec
test_lint_buildspec() {
    log_info "Testing lint buildspec build phase..."
    
    cd modules/api
    
    # Run linting
    if uv run ruff check . && uv run ruff format --check .; then
        log_success "Lint buildspec build phase completed"
        cd ../..
        return 0
    else
        log_error "Lint buildspec build phase failed"
        cd ../..
        return 1
    fi
}

# Test test buildspec
test_test_buildspec() {
    log_info "Testing test buildspec build phase..."
    
    cd modules/api
    
    # Run tests
    if uv run pytest tests/ -v; then
        log_success "Test buildspec build phase completed"
        cd ../..
        return 0
    else
        log_error "Test buildspec build phase failed"
        cd ../..
        return 1
    fi
}

# Test SCA buildspec
test_sca_buildspec() {
    log_info "Testing SCA buildspec build phase..."
    
    # In local environment, this should be skipped
    if [ "${STAGE_NAME}" = "local" ]; then
        log_info "Local environment detected - skipping CodeGuru Security scan"
        
        # Create dummy result file
        SCAN_NAME="${SERVICE_NAME}-${STAGE_NAME}-sca-$(date +%s)"
        echo '{"findings": [], "status": "skipped_local_env"}' > "$SCAN_NAME.json"
        
        log_success "SCA buildspec build phase completed (skipped for local)"
        return 0
    else
        log_warning "SCA buildspec requires real AWS services"
        return 1
    fi
}

# Test SAST buildspec
test_sast_buildspec() {
    log_info "Testing SAST buildspec build phase..."
    
    # In local environment, this should be skipped
    if [ "${STAGE_NAME}" = "local" ]; then
        log_info "Local environment detected - skipping CodeGuru Security scan"
        
        # Create dummy result file
        SCAN_NAME="${SERVICE_NAME}-${STAGE_NAME}-sast-$(date +%s)"
        echo '{"findings": [], "status": "skipped_local_env"}' > "$SCAN_NAME.json"
        
        log_success "SAST buildspec build phase completed (skipped for local)"
        return 0
    else
        log_warning "SAST buildspec requires real AWS services"
        return 1
    fi
}

# Test deploy_lambda buildspec
test_deploy_lambda_buildspec() {
    log_info "Testing deploy_lambda buildspec build phase..."
    
    # Check if LocalStack is running
    if ! curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null 2>&1; then
        log_warning "LocalStack is not running. Lambda deployment test will be skipped."
        return 1
    fi
    
    # Source LocalStack helpers
    source "$PROJECT_ROOT/scripts/localstack-helpers.sh"
    setup_localstack_env
    
    # Create Lambda package
    cd modules/api
    zip -r ../../lambda-package.zip . -x "__pycache__/*" "*.pyc" "tests/*"
    cd ../..
    
    # Deploy to LocalStack
    if deploy_lambda_to_localstack \
        "codepipeline-${STAGE_NAME}-lambda-api" \
        "lambda-package.zip" \
        "main.handler"; then
        log_success "deploy_lambda buildspec build phase completed (LocalStack)"
        return 0
    else
        log_error "deploy_lambda buildspec build phase failed"
        return 1
    fi
}

# Test deploy-ecs buildspec
test_deploy_ecs_buildspec() {
    log_info "Testing deploy-ecs buildspec build phase..."
    
    # Check if LocalStack is running
    if ! curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null 2>&1; then
        log_warning "LocalStack is not running. ECS deployment test will be skipped."
        return 1
    fi
    
    log_info "ECS deployment simulation (LocalStack has limited ECS support)"
    
    # Simulate ECS deployment steps
    log_info "Building Docker image..."
    if docker build -t codepipeline-local-api:latest modules/api/; then
        log_success "Docker image built successfully"
    else
        log_error "Docker image build failed"
        return 1
    fi
    
    log_success "Deploy-ecs buildspec build phase completed (simulated)"
    return 0
}

# Test deploy_ec2 buildspec
test_deploy_ec2_buildspec() {
    log_info "Testing deploy_ec2 buildspec build phase..."
    
    # Check if LocalStack is running
    if ! curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null 2>&1; then
        log_warning "LocalStack is not running. EC2 deployment test will be skipped."
        return 1
    fi
    
    log_info "EC2 deployment simulation (LocalStack has limited CodeDeploy support)"
    
    # Create deployment package
    if zip -r deployment-package.zip . \
        -x "*.git*" "node_modules/*" "*.pyc" "__pycache__/*" ".venv/*" \
        "cdk.out/*" "*.zip"; then
        log_success "Deployment package created"
    else
        log_error "Failed to create deployment package"
        return 1
    fi
    
    log_success "deploy_ec2 buildspec build phase completed (simulated)"
    return 0
}

# Test all buildspecs
test_all_buildspecs() {
    log_info "Testing all CodePipeline buildspecs..."
    
    local buildspecs=("cache" "lint" "test" "sca" "sast")
    local failed_buildspecs=()
    
    for buildspec in "${buildspecs[@]}"; do
        if test_buildspec_phases "$buildspec"; then
            log_success "Buildspec '$buildspec' completed successfully"
        else
            log_error "Buildspec '$buildspec' failed"
            failed_buildspecs+=("$buildspec")
        fi
    done
    
    # Test deploy buildspecs separately (they require LocalStack)
    local deploy_buildspecs=("deploy_lambda" "deploy-ecs" "deploy_ec2")
    
    for buildspec in "${deploy_buildspecs[@]}"; do
        if test_buildspec_phases "$buildspec"; then
            log_success "Deploy buildspec '$buildspec' completed successfully"
        else
            log_warning "Deploy buildspec '$buildspec' failed (may require LocalStack)"
        fi
    done
    
    if [ ${#failed_buildspecs[@]} -eq 0 ]; then
        log_success "All testable CodePipeline buildspecs completed successfully"
        return 0
    else
        log_error "Failed buildspecs: ${failed_buildspecs[*]}"
        return 1
    fi
}

# List available buildspecs
list_buildspecs() {
    log_info "Available CodePipeline buildspecs:"
    
    cd "$PROJECT_ROOT"
    
    if [ -d codepipeline/buildspecs ]; then
        for file in codepipeline/buildspecs/*.yml; do
            if [ -f "$file" ]; then
                local buildspec_name=$(basename "$file" .yml)
                echo "  - $buildspec_name"
            fi
        done
        log_success "Buildspec listing completed"
    else
        log_error "Buildspecs directory not found"
    fi
}

# Show help
show_help() {
    cat << EOF
CodePipeline Local Test Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -l, --list          List available buildspecs
    -b, --buildspec BS  Test specific buildspec
    --setup-only        Only setup environment, don't run tests

EXAMPLES:
    $0                  # Test all buildspecs
    $0 -b lint          # Test only lint buildspec
    $0 -b deploy_lambda # Test lambda deployment buildspec
    $0 --list           # List available buildspecs

PREREQUISITES:
    - AWS CLI
    - jq
    - Docker
    - LocalStack (for deployment tests)

BUILDSPECS:
    - cache             # Dependency caching
    - lint              # Static analysis
    - test              # Unit tests
    - sca               # Security composition analysis (skipped locally)
    - sast              # Static application security testing (skipped locally)
    - deploy_lambda     # Lambda deployment (requires LocalStack)
    - deploy-ecs        # ECS deployment (requires LocalStack)
    - deploy_ec2        # EC2 deployment (requires LocalStack)

EOF
}

# Main execution
main() {
    local specific_buildspec=""
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
            -b|--buildspec)
                specific_buildspec="$2"
                shift 2
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
    
    log_info "Starting CodePipeline buildspec local testing..."
    
    # Check prerequisites
    check_prerequisites
    
    # Setup environment
    setup_environment
    
    if [ "$list_only" = true ]; then
        list_buildspecs
        exit 0
    fi
    
    if [ "$setup_only" = true ]; then
        log_success "Environment setup completed. You can now test buildspecs manually."
        exit 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Run specific buildspec or all buildspecs
    if [ -n "$specific_buildspec" ]; then
        log_info "Testing specific buildspec: $specific_buildspec"
        if test_buildspec_phases "$specific_buildspec"; then
            log_success "Buildspec '$specific_buildspec' completed successfully"
        else
            log_error "Buildspec '$specific_buildspec' failed"
            exit 1
        fi
    else
        # Run all buildspecs
        test_all_buildspecs
    fi
    
    log_success "CodePipeline buildspec local testing completed!"
}

# Run main function
main "$@"
#!/bin/bash
# GitLab CI/CD Lambda デプロイスクリプト

set -e

echo "=== Lambda Deployment Script ==="

SERVICE_NAME=${SERVICE_NAME:-"cicd-comparison"}
STAGE_NAME=${STAGE_NAME:-"local"}
CICD_TOOL=${CICD_TOOL:-"gitlab"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"ap-northeast-1"}
SAM_STACK_NAME="${CICD_TOOL}-${STAGE_NAME}-sam-stack"

echo "Service: $SERVICE_NAME"
echo "Stage: $STAGE_NAME"
echo "Region: $AWS_DEFAULT_REGION"

# SAM CLIのインストール
echo "Installing SAM CLI..."
wget -q https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip -q aws-sam-cli-linux-x86_64.zip -d sam-installation
./sam-installation/install
sam --version

# SAMビルド
echo "Building GitLab SAM application..."
sam build --template-file template-gitlab.yaml

# SAMデプロイ
echo "Deploying GitLab SAM application..."
sam deploy \
    --config-file samconfig.toml \
    --config-env gitlab \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset

# デプロイ確認
echo "Verifying GitLab Lambda deployment..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name ${SAM_STACK_NAME} \
    --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
    --output text \
    --region $AWS_DEFAULT_REGION)

echo "API Endpoint: $API_ENDPOINT"

# ヘルスチェック
echo "Performing health check..."
curl -f "$API_ENDPOINT/health" || {
    echo "ERROR: Lambda health check failed"
    exit 1
}

echo "GitLab Lambda deployment completed successfully"
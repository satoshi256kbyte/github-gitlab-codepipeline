#!/bin/bash

# LocalStack initialization script
# This script sets up the basic AWS resources in LocalStack for CI/CD testing

set -e

# Load environment variables
if [ -f .env.localstack ]; then
    export $(cat .env.localstack | grep -v '^#' | xargs)
fi

# LocalStack endpoint
ENDPOINT=${LOCALSTACK_ENDPOINT:-http://localhost:4566}
REGION=${AWS_DEFAULT_REGION:-ap-northeast-1}

echo "🚀 Initializing LocalStack environment..."
echo "Endpoint: $ENDPOINT"
echo "Region: $REGION"

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
WAIT_COUNT=0
MAX_WAIT=30
until curl -s $ENDPOINT/_localstack/health | grep -q -E '"s3": "(available|running)"'; do
    echo "Waiting for LocalStack... (attempt $((WAIT_COUNT + 1))/$MAX_WAIT)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "❌ LocalStack failed to start within timeout"
        exit 1
    fi
done

echo "✅ LocalStack is ready!"

# Create S3 buckets for CI/CD artifacts
echo "📦 Creating S3 buckets..."
aws --endpoint-url=$ENDPOINT s3 mb s3://github-local-artifacts --region $REGION || true
aws --endpoint-url=$ENDPOINT s3 mb s3://gitlab-local-artifacts --region $REGION || true
aws --endpoint-url=$ENDPOINT s3 mb s3://codepipeline-local-artifacts --region $REGION || true

# Create ECR repositories (skip if not available in LocalStack free version)
echo "🐳 Creating ECR repositories..."
if aws --endpoint-url=$ENDPOINT ecr describe-repositories --region $REGION >/dev/null 2>&1; then
    aws --endpoint-url=$ENDPOINT ecr create-repository --repository-name github-local-api --region $REGION 2>/dev/null || echo "  ⚠️  ECR repository github-local-api already exists or failed to create"
    aws --endpoint-url=$ENDPOINT ecr create-repository --repository-name gitlab-local-api --region $REGION 2>/dev/null || echo "  ⚠️  ECR repository gitlab-local-api already exists or failed to create"
    aws --endpoint-url=$ENDPOINT ecr create-repository --repository-name codepipeline-local-api --region $REGION 2>/dev/null || echo "  ⚠️  ECR repository codepipeline-local-api already exists or failed to create"
else
    echo "  ⚠️  ECR service not available in LocalStack free version - skipping ECR repository creation"
fi

# Create CloudWatch Log Groups
echo "📝 Creating CloudWatch Log Groups..."
aws --endpoint-url=$ENDPOINT logs create-log-group --log-group-name /aws/lambda/github-local-lambda-api --region $REGION || true
aws --endpoint-url=$ENDPOINT logs create-log-group --log-group-name /aws/lambda/gitlab-local-lambda-api --region $REGION || true
aws --endpoint-url=$ENDPOINT logs create-log-group --log-group-name /aws/lambda/codepipeline-local-lambda-api --region $REGION || true

aws --endpoint-url=$ENDPOINT logs create-log-group --log-group-name /aws/ecs/github-local-ecs --region $REGION || true
aws --endpoint-url=$ENDPOINT logs create-log-group --log-group-name /aws/ecs/gitlab-local-ecs --region $REGION || true
aws --endpoint-url=$ENDPOINT logs create-log-group --log-group-name /aws/ecs/codepipeline-local-ecs --region $REGION || true

# Create IAM roles for local testing
echo "🔐 Creating IAM roles..."

# Lambda execution role
cat > /tmp/lambda-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws --endpoint-url=$ENDPOINT iam create-role \
    --role-name LocalStackLambdaExecutionRole \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    --region $REGION || true

aws --endpoint-url=$ENDPOINT iam attach-role-policy \
    --role-name LocalStackLambdaExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    --region $REGION || true

# ECS task execution role
cat > /tmp/ecs-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws --endpoint-url=$ENDPOINT iam create-role \
    --role-name LocalStackECSTaskExecutionRole \
    --assume-role-policy-document file:///tmp/ecs-trust-policy.json \
    --region $REGION || true

aws --endpoint-url=$ENDPOINT iam attach-role-policy \
    --role-name LocalStackECSTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    --region $REGION || true

# Clean up temporary files
rm -f /tmp/lambda-trust-policy.json /tmp/ecs-trust-policy.json

echo "🎉 LocalStack initialization completed!"
echo ""
echo "📋 Available services:"
echo "  - S3 buckets: github-local-artifacts, gitlab-local-artifacts, codepipeline-local-artifacts"
echo "  - ECR repositories: github-local-api, gitlab-local-api, codepipeline-local-api"
echo "  - CloudWatch Log Groups: Created for Lambda and ECS services"
echo "  - IAM roles: LocalStackLambdaExecutionRole, LocalStackECSTaskExecutionRole"
echo ""
echo "🌐 LocalStack Web UI: http://localhost:8080"
echo "🔗 LocalStack Endpoint: $ENDPOINT"
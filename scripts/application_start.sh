#!/bin/bash

# ECS Blue/Green デプロイ - ApplicationStart フック
# アプリケーション開始時に実行される

set -e

echo "$(date): ApplicationStart hook started"

# アプリケーションの起動確認
CLUSTER_NAME="${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}"
SERVICE_NAME="${SERVICE_NAME:-cicd-comparison-local-ecs-service}"

echo "Verifying application startup..."

# サービスの詳細情報を取得
SERVICE_INFO=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0]')

RUNNING_COUNT=$(echo "$SERVICE_INFO" | jq -r '.runningCount')
DESIRED_COUNT=$(echo "$SERVICE_INFO" | jq -r '.desiredCount')

echo "Running tasks: $RUNNING_COUNT, Desired tasks: $DESIRED_COUNT"

if [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" -gt 0 ]; then
    echo "Application started successfully"
else
    echo "Application startup verification failed"
    exit 1
fi

echo "$(date): ApplicationStart hook completed successfully"
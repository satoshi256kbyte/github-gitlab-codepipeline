#!/bin/bash

# ECS Blue/Green デプロイ - ApplicationStop フック
# アプリケーション停止時に実行される

set -e

echo "$(date): ApplicationStop hook started"

# 古いタスクの停止確認
CLUSTER_NAME="${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}"
SERVICE_NAME="${SERVICE_NAME:-cicd-comparison-local-ecs-service}"

echo "Checking for old tasks to stop..."

# 実行中のタスクを確認
TASKS=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --desired-status RUNNING \
    --query 'taskArns' \
    --output text)

if [ -n "$TASKS" ] && [ "$TASKS" != "None" ]; then
    echo "Found running tasks, monitoring graceful shutdown..."
    
    # タスクの詳細を表示
    aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks $TASKS \
        --query 'tasks[].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus}' \
        --output table
else
    echo "No running tasks found"
fi

echo "$(date): ApplicationStop hook completed successfully"
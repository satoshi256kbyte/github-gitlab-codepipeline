#!/bin/bash

# ECS Blue/Green デプロイ - AfterInstall フック
# 新しいタスク定義のデプロイ後に実行される

set -e

echo "$(date): AfterInstall hook started"

# 新しいタスクの起動を確認
echo "Checking new task deployment status:"
aws ecs describe-services \
    --cluster "${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}" \
    --services "${SERVICE_NAME:-cicd-comparison-local-ecs-service}" \
    --query 'services[0].{Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount}' \
    --output table

# タスクが正常に起動するまで待機
echo "Waiting for tasks to be in RUNNING state..."
aws ecs wait services-stable \
    --cluster "${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}" \
    --services "${SERVICE_NAME:-cicd-comparison-local-ecs-service}"

echo "$(date): AfterInstall hook completed successfully"
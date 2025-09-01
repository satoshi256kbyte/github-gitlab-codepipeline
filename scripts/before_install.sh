#!/bin/bash

# ECS Blue/Green デプロイ - BeforeInstall フック
# 新しいタスク定義のデプロイ前に実行される

set -e

echo "$(date): BeforeInstall hook started"

# ログ出力
echo "Current ECS service status:"
aws ecs describe-services \
    --cluster "${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}" \
    --services "${SERVICE_NAME:-cicd-comparison-local-ecs-service}" \
    --query 'services[0].{Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount}' \
    --output table

echo "$(date): BeforeInstall hook completed successfully"
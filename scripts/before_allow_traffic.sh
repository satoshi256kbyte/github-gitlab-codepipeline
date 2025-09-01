#!/bin/bash

# ECS Blue/Green デプロイ - BeforeAllowTraffic フック
# トラフィックを新しいタスクに切り替える前に実行される

set -e

echo "$(date): BeforeAllowTraffic hook started"

# ヘルスチェック実行
CLUSTER_NAME="${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}"
SERVICE_NAME="${SERVICE_NAME:-cicd-comparison-local-ecs-service}"
ALB_TARGET_GROUP_ARN="${ALB_TARGET_GROUP_ARN}"

echo "Performing health checks before allowing traffic..."

# ECSサービスのヘルスチェック
echo "Checking ECS service health..."
aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].{Status:status,RunningCount:runningCount,HealthyCount:runningCount}' \
    --output table

# ALBターゲットグループのヘルスチェック（設定されている場合）
if [ -n "$ALB_TARGET_GROUP_ARN" ]; then
    echo "Checking ALB target group health..."
    HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
        --target-group-arn "$ALB_TARGET_GROUP_ARN" \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' \
        --output json | jq length)
    
    echo "Healthy targets in ALB: $HEALTHY_TARGETS"
    
    if [ "$HEALTHY_TARGETS" -eq 0 ]; then
        echo "No healthy targets found in ALB target group"
        exit 1
    fi
fi

# アプリケーションレベルのヘルスチェック
echo "Performing application-level health check..."

# タスクのプライベートIPを取得してヘルスチェック
TASK_ARNS=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --desired-status RUNNING \
    --query 'taskArns' \
    --output text)

if [ -n "$TASK_ARNS" ] && [ "$TASK_ARNS" != "None" ]; then
    for TASK_ARN in $TASK_ARNS; do
        echo "Checking health for task: $TASK_ARN"
        
        # タスクの詳細情報を取得
        TASK_DETAIL=$(aws ecs describe-tasks \
            --cluster "$CLUSTER_NAME" \
            --tasks "$TASK_ARN" \
            --query 'tasks[0]')
        
        HEALTH_STATUS=$(echo "$TASK_DETAIL" | jq -r '.healthStatus // "UNKNOWN"')
        LAST_STATUS=$(echo "$TASK_DETAIL" | jq -r '.lastStatus')
        
        echo "Task health status: $HEALTH_STATUS, Last status: $LAST_STATUS"
        
        if [ "$HEALTH_STATUS" != "HEALTHY" ] && [ "$HEALTH_STATUS" != "UNKNOWN" ]; then
            echo "Task is not healthy: $HEALTH_STATUS"
            exit 1
        fi
    done
else
    echo "No running tasks found"
    exit 1
fi

echo "All health checks passed successfully"
echo "$(date): BeforeAllowTraffic hook completed successfully"
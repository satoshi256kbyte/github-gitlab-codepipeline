#!/bin/bash

# ECS Blue/Green デプロイ - AfterAllowTraffic フック
# トラフィックが新しいタスクに切り替わった後に実行される

set -e

echo "$(date): AfterAllowTraffic hook started"

# デプロイ完了後の確認
CLUSTER_NAME="${CLUSTER_NAME:-cicd-comparison-local-ecs-cluster}"
SERVICE_NAME="${SERVICE_NAME:-cicd-comparison-local-ecs-service}"
ALB_TARGET_GROUP_ARN="${ALB_TARGET_GROUP_ARN}"

echo "Verifying deployment completion..."

# ECSサービスの最終状態確認
echo "Final ECS service status:"
aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].{Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount,TaskDefinition:taskDefinition}' \
    --output table

# ALBターゲットグループの最終状態確認
if [ -n "$ALB_TARGET_GROUP_ARN" ]; then
    echo "Final ALB target group status:"
    aws elbv2 describe-target-health \
        --target-group-arn "$ALB_TARGET_GROUP_ARN" \
        --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Description:TargetHealth.Description}' \
        --output table
fi

# デプロイメント履歴の記録
echo "Recording deployment completion..."
DEPLOYMENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TASK_DEFINITION=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].taskDefinition' \
    --output text)

echo "Deployment completed successfully at $DEPLOYMENT_TIME"
echo "Active task definition: $TASK_DEFINITION"

# 成功通知（オプション）
if [ -n "$SNS_TOPIC_ARN" ]; then
    aws sns publish \
        --topic-arn "$SNS_TOPIC_ARN" \
        --message "ECS Blue/Green deployment completed successfully for service $SERVICE_NAME at $DEPLOYMENT_TIME" \
        --subject "ECS Deployment Success"
fi

echo "$(date): AfterAllowTraffic hook completed successfully"
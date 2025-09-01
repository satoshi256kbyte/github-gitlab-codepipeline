#!/bin/bash
# GitLab CI/CD ECS Blue/Green デプロイスクリプト

set -e

echo "=== ECS Blue/Green Deployment Script ==="

SERVICE_NAME=${SERVICE_NAME:-"cicd-comparison"}
STAGE_NAME=${STAGE_NAME:-"local"}
CICD_TOOL=${CICD_TOOL:-"gitlab"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"ap-northeast-1"}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
CI_COMMIT_SHA=${CI_COMMIT_SHA}
IMAGE_REPO_NAME="${CICD_TOOL}-${STAGE_NAME}-ecr-api"
APPLICATION_NAME="${CICD_TOOL}-${STAGE_NAME}-codedeploy-ecs"
DEPLOYMENT_GROUP="${CICD_TOOL}-${STAGE_NAME}-deployment-group-ecs"
ALB_NAME_ECS="${CICD_TOOL}-${STAGE_NAME}-alb-ecs"
DEPLOYMENT_TIMEOUT=${DEPLOYMENT_TIMEOUT:-1800}

echo "Service: $SERVICE_NAME"
echo "Stage: $STAGE_NAME"
echo "Region: $AWS_DEFAULT_REGION"
echo "Account ID: $AWS_ACCOUNT_ID"
echo "Commit SHA: $CI_COMMIT_SHA"

# ECRログイン
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
    docker login --username AWS --password-stdin \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

# Dockerイメージビルド
echo "Building Docker image..."
cd modules/api
docker build -t $IMAGE_REPO_NAME:$CI_COMMIT_SHA .
docker tag $IMAGE_REPO_NAME:$CI_COMMIT_SHA \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$CI_COMMIT_SHA
docker tag $IMAGE_REPO_NAME:$CI_COMMIT_SHA \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:latest

# ECRプッシュ
echo "Pushing Docker image to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$CI_COMMIT_SHA
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:latest

cd ../..

# タスク定義更新
echo "Updating GitLab task definition..."
ImageURI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$CI_COMMIT_SHA
sed "s|<IMAGE1_NAME>|$ImageURI|g" taskdef-gitlab.json > taskdef-updated.json

# タスク定義登録
echo "Registering new task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://taskdef-updated.json \
    --region $AWS_DEFAULT_REGION \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
echo "Task Definition ARN: $TASK_DEF_ARN"

# appspec.yml更新
echo "Updating GitLab appspec.yml..."
sed "s|\"<TASK_DEFINITION>\"|\"$TASK_DEF_ARN\"|g" appspec-gitlab.yml > appspec-updated.yml

# CodeDeployデプロイ作成
echo "Creating CodeDeploy deployment..."
CONTENT=$(cat appspec-updated.yml | jq -Rs .)
SHA256=$(cat appspec-updated.yml | sha256sum | awk '{print $1}')

cat > deployment.json << EOF
{
    "applicationName": "$APPLICATION_NAME",
    "deploymentGroupName": "$DEPLOYMENT_GROUP",
    "deploymentConfigName": "CodeDeployDefault.ECSAllAtOnce",
    "revision": {
        "revisionType": "AppSpecContent",
        "appSpecContent": {
            "content": $CONTENT,
            "sha256": "$SHA256"
        }
    }
}
EOF

DEPLOYMENT_ID=$(aws deploy create-deployment \
    --cli-input-json file://deployment.json \
    --region $AWS_DEFAULT_REGION \
    --query "deploymentId" \
    --output text)
echo "Deployment ID: $DEPLOYMENT_ID"

# デプロイ完了待機
echo "Waiting for deployment to complete..."
INTERVAL=30
ELAPSED=0

while true; do
    STATUS=$(aws deploy get-deployment \
        --deployment-id "$DEPLOYMENT_ID" \
        --region $AWS_DEFAULT_REGION \
        --query "deploymentInfo.status" \
        --output text)

    echo "[$ELAPSED sec] Deployment status: $STATUS"

    if [[ "$STATUS" == "Succeeded" ]]; then
        echo "ECS deployment succeeded."
        break
    fi

    if [[ "$STATUS" == "Failed" || "$STATUS" == "Stopped" ]]; then
        echo "ERROR: ECS deployment failed or was stopped."
        exit 1
    fi

    if [[ $ELAPSED -ge $DEPLOYMENT_TIMEOUT ]]; then
        echo "ERROR: ECS deployment timeout after $DEPLOYMENT_TIMEOUT seconds."
        exit 1
    fi

    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

# デプロイ確認
echo "Verifying GitLab ECS deployment..."
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names ${ALB_NAME_ECS} \
    --query "LoadBalancers[0].DNSName" \
    --output text \
    --region $AWS_DEFAULT_REGION)
echo "ALB DNS: $ALB_DNS"

# ヘルスチェック
echo "Performing GitLab ECS health check..."
curl -f "http://$ALB_DNS:8081/health" || {
    echo "ERROR: GitLab ECS health check failed"
    exit 1
}

echo "GitLab ECS deployment completed successfully"
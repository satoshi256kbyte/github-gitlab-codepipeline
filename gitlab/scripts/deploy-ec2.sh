#!/bin/bash
# GitLab CI/CD EC2 CodeDeploy Blue/Green デプロイスクリプト

set -e

echo "=== EC2 CodeDeploy Blue/Green Deployment Script ==="

SERVICE_NAME=${SERVICE_NAME:-"cicd-comparison"}
STAGE_NAME=${STAGE_NAME:-"local"}
CICD_TOOL=${CICD_TOOL:-"gitlab"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"ap-northeast-1"}
CI_COMMIT_SHA=${CI_COMMIT_SHA}
APPLICATION_NAME_EC2="gitlab-local-codedeploy-app"
DEPLOYMENT_GROUP_EC2="gitlab-local-codedeploy-dg"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="comparison-local-${ACCOUNT_ID}-artifact-bucket"
ALB_NAME_EC2="${CICD_TOOL}-${STAGE_NAME}-alb-ec2"
DEPLOYMENT_TIMEOUT=${DEPLOYMENT_TIMEOUT:-1800}

echo "Service: $SERVICE_NAME"
echo "Stage: $STAGE_NAME"
echo "Region: $AWS_DEFAULT_REGION"
echo "Commit SHA: $CI_COMMIT_SHA"

# デプロイパッケージ作成
echo "Creating GitLab deployment package..."
zip -r deployment-package.zip \
    modules/api/ \
    scripts/ \
    appspec-ec2-gitlab.yml \
    -x "modules/api/.venv/*" \
        "modules/api/__pycache__/*" \
        "modules/api/*.pyc"

# S3アップロード
echo "Uploading GitLab deployment package to S3..."
S3_KEY="deployments/$(date +%Y%m%d-%H%M%S)-${CI_COMMIT_SHA}.zip"
aws s3 cp deployment-package.zip \
    s3://$S3_BUCKET/$S3_KEY \
    --region $AWS_DEFAULT_REGION

# CodeDeployデプロイ作成
echo "Creating CodeDeploy deployment..."
cat > ec2-deployment.json << EOF
{
    "applicationName": "$APPLICATION_NAME_EC2",
    "deploymentGroupName": "$DEPLOYMENT_GROUP_EC2",
    "deploymentConfigName": "CodeDeployDefault.EC2AllAtOnceBlueGreen",
    "revision": {
        "revisionType": "S3",
        "s3Location": {
            "bucket": "$S3_BUCKET",
            "key": "$S3_KEY",
            "bundleType": "zip"
        }
    }
}
EOF

DEPLOYMENT_ID=$(aws deploy create-deployment \
    --cli-input-json file://ec2-deployment.json \
    --region $AWS_DEFAULT_REGION \
    --query "deploymentId" \
    --output text)
echo "Deployment ID: $DEPLOYMENT_ID"

# デプロイ完了待機
echo "Waiting for EC2 deployment to complete..."
INTERVAL=30
ELAPSED=0

while true; do
    STATUS=$(aws deploy get-deployment \
        --deployment-id "$DEPLOYMENT_ID" \
        --region $AWS_DEFAULT_REGION \
        --query "deploymentInfo.status" \
        --output text)

    echo "[$ELAPSED sec] EC2 Deployment status: $STATUS"

    if [[ "$STATUS" == "Succeeded" ]]; then
        echo "EC2 deployment succeeded."
        break
    fi

    if [[ "$STATUS" == "Failed" || "$STATUS" == "Stopped" ]]; then
        echo "ERROR: EC2 deployment failed or was stopped."
        exit 1
    fi

    if [[ $ELAPSED -ge $DEPLOYMENT_TIMEOUT ]]; then
        echo "ERROR: EC2 deployment timeout after $DEPLOYMENT_TIMEOUT seconds."
        exit 1
    fi

    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

# デプロイ確認
echo "Verifying GitLab EC2 deployment..."
ALB_DNS_EC2=$(aws elbv2 describe-load-balancers \
    --names ${ALB_NAME_EC2} \
    --query "LoadBalancers[0].DNSName" \
    --output text \
    --region $AWS_DEFAULT_REGION)
echo "ALB DNS: $ALB_DNS_EC2"

# ヘルスチェック
echo "Performing GitLab EC2 health check..."
curl -f "http://$ALB_DNS_EC2:8081/health" || {
    echo "ERROR: GitLab EC2 health check failed"
    exit 1
}

echo "GitLab EC2 deployment completed successfully"
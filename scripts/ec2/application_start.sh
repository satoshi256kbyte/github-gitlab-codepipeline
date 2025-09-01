#!/bin/bash

# EC2 CodeDeploy - ApplicationStart フック
# アプリケーションの開始時に実行される

set -e

echo "$(date): ApplicationStart hook started"

APP_DIR="/opt/cicd-comparison-api"
SERVICE_NAME="cicd-comparison-api"

# サービスの開始
echo "Starting $SERVICE_NAME service..."
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# サービスの起動確認
echo "Waiting for service to start..."
sleep 5

# サービスステータスの確認
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Service $SERVICE_NAME is running"
else
    echo "Service $SERVICE_NAME failed to start"
    systemctl status "$SERVICE_NAME"
    exit 1
fi

# アプリケーションのヘルスチェック
echo "Performing application health check..."
HEALTH_CHECK_TIMEOUT=60
HEALTH_CHECK_INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $HEALTH_CHECK_TIMEOUT ]; do
    if "$APP_DIR/health_check.sh"; then
        echo "Application health check passed"
        break
    fi
    
    echo "Health check failed, waiting $HEALTH_CHECK_INTERVAL seconds..."
    sleep $HEALTH_CHECK_INTERVAL
    ELAPSED=$((ELAPSED + HEALTH_CHECK_INTERVAL))
done

if [ $ELAPSED -ge $HEALTH_CHECK_TIMEOUT ]; then
    echo "Application health check timed out after $HEALTH_CHECK_TIMEOUT seconds"
    systemctl status "$SERVICE_NAME"
    journalctl -u "$SERVICE_NAME" --no-pager -n 50
    exit 1
fi

# ポートの確認
echo "Checking if application is listening on port 8000..."
if netstat -tlnp | grep -q ":8000 "; then
    echo "Application is listening on port 8000"
else
    echo "Application is not listening on port 8000"
    netstat -tlnp | grep ":8000" || echo "No process found on port 8000"
    exit 1
fi

echo "$(date): ApplicationStart hook completed successfully"
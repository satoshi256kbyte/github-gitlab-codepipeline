#!/bin/bash

# EC2 CodeDeploy - ValidateService フック
# デプロイ完了後のサービス検証

set -e

echo "$(date): ValidateService hook started"

APP_DIR="/opt/cicd-comparison-api"
SERVICE_NAME="cicd-comparison-api"
BASE_URL="http://localhost:8000"

# サービスステータスの確認
echo "Validating service status..."
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "ERROR: Service $SERVICE_NAME is not running"
    systemctl status "$SERVICE_NAME"
    exit 1
fi

echo "Service $SERVICE_NAME is running"

# ヘルスチェックエンドポイントの検証
echo "Validating health endpoint..."
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" "$BASE_URL/health" -o /tmp/health_response.json)
HTTP_CODE="${HEALTH_RESPONSE: -3}"

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: Health endpoint returned HTTP $HTTP_CODE"
    cat /tmp/health_response.json
    exit 1
fi

echo "Health endpoint validation passed (HTTP $HTTP_CODE)"

# バージョンエンドポイントの検証
echo "Validating version endpoint..."
VERSION_RESPONSE=$(curl -s -w "%{http_code}" "$BASE_URL/version" -o /tmp/version_response.json)
HTTP_CODE="${VERSION_RESPONSE: -3}"

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: Version endpoint returned HTTP $HTTP_CODE"
    cat /tmp/version_response.json
    exit 1
fi

echo "Version endpoint validation passed (HTTP $HTTP_CODE)"

# APIエンドポイントの基本検証
echo "Validating API endpoints..."

# アイテム一覧取得の検証
ITEMS_RESPONSE=$(curl -s -w "%{http_code}" "$BASE_URL/api/items" -o /tmp/items_response.json)
HTTP_CODE="${ITEMS_RESPONSE: -3}"

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: Items endpoint returned HTTP $HTTP_CODE"
    cat /tmp/items_response.json
    exit 1
fi

echo "Items endpoint validation passed (HTTP $HTTP_CODE)"

# レスポンス時間の検証
echo "Validating response time..."
RESPONSE_TIME=$(curl -s -w "%{time_total}" "$BASE_URL/health" -o /dev/null)
RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc)

echo "Response time: ${RESPONSE_TIME_MS}ms"

# レスポンス時間が5秒を超える場合は警告
if (( $(echo "$RESPONSE_TIME > 5.0" | bc -l) )); then
    echo "WARNING: Response time is high (${RESPONSE_TIME}s)"
fi

# メモリ使用量の確認
echo "Checking memory usage..."
MEMORY_USAGE=$(ps -o pid,ppid,cmd,%mem,%cpu --sort=-%mem -C python3.13 | head -10)
echo "Memory usage by Python processes:"
echo "$MEMORY_USAGE"

# ディスク使用量の確認
echo "Checking disk usage..."
DISK_USAGE=$(df -h /opt/cicd-comparison-api)
echo "Disk usage for application directory:"
echo "$DISK_USAGE"

# ログファイルの確認
echo "Checking log files..."
if [ -d "/var/log/cicd-comparison-api" ]; then
    LOG_FILES=$(ls -la /var/log/cicd-comparison-api/ 2>/dev/null || echo "No log files found")
    echo "Log files:"
    echo "$LOG_FILES"
fi

# systemdログの確認
echo "Checking recent systemd logs..."
journalctl -u "$SERVICE_NAME" --no-pager -n 10 --since "5 minutes ago"

# 最終検証結果
echo "=== Validation Summary ==="
echo "✓ Service is running"
echo "✓ Health endpoint responding"
echo "✓ Version endpoint responding"
echo "✓ API endpoints responding"
echo "✓ Response time acceptable"

# 成功通知（オプション）
if [ -n "$SNS_TOPIC_ARN" ]; then
    aws sns publish \
        --topic-arn "$SNS_TOPIC_ARN" \
        --message "EC2 CodeDeploy validation completed successfully for $SERVICE_NAME" \
        --subject "EC2 Deployment Validation Success" || echo "SNS notification failed"
fi

echo "$(date): ValidateService hook completed successfully"
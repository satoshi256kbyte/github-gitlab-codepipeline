#!/bin/bash

# EC2 CodeDeploy - ApplicationStop フック
# アプリケーションの停止時に実行される

set -e

echo "$(date): ApplicationStop hook started"

SERVICE_NAME="cicd-comparison-api"

# サービスが存在するかチェック
if systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
    echo "Stopping $SERVICE_NAME service..."
    
    # サービスが実行中かチェック
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Service is running, stopping gracefully..."
        
        # グレースフルシャットダウンの実行
        systemctl stop "$SERVICE_NAME"
        
        # 停止の確認
        STOP_TIMEOUT=30
        ELAPSED=0
        
        while systemctl is-active --quiet "$SERVICE_NAME" && [ $ELAPSED -lt $STOP_TIMEOUT ]; do
            echo "Waiting for service to stop... ($ELAPSED/$STOP_TIMEOUT seconds)"
            sleep 2
            ELAPSED=$((ELAPSED + 2))
        done
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            echo "Service did not stop gracefully, forcing stop..."
            systemctl kill "$SERVICE_NAME"
            sleep 2
        fi
        
        echo "Service stopped successfully"
    else
        echo "Service is not running"
    fi
    
    # サービスの無効化
    systemctl disable "$SERVICE_NAME" || echo "Service was not enabled"
else
    echo "Service $SERVICE_NAME does not exist"
fi

# プロセスの強制終了（念のため）
echo "Checking for any remaining processes..."
PIDS=$(pgrep -f "uvicorn.*main:app" || true)
if [ -n "$PIDS" ]; then
    echo "Found remaining processes: $PIDS"
    echo "Terminating remaining processes..."
    kill -TERM $PIDS || true
    sleep 5
    
    # まだ残っている場合は強制終了
    PIDS=$(pgrep -f "uvicorn.*main:app" || true)
    if [ -n "$PIDS" ]; then
        echo "Force killing remaining processes: $PIDS"
        kill -KILL $PIDS || true
    fi
fi

# ポート8000の使用状況確認
echo "Checking port 8000 usage..."
PORT_USAGE=$(netstat -tlnp | grep ":8000 " || true)
if [ -n "$PORT_USAGE" ]; then
    echo "Port 8000 is still in use:"
    echo "$PORT_USAGE"
    
    # ポートを使用しているプロセスを特定して終了
    PID=$(echo "$PORT_USAGE" | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ] && [ "$PID" != "-" ]; then
        echo "Killing process using port 8000: PID $PID"
        kill -KILL "$PID" || true
    fi
else
    echo "Port 8000 is free"
fi

echo "$(date): ApplicationStop hook completed successfully"
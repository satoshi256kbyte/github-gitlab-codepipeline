#!/bin/bash

# EC2 CodeDeploy - BeforeInstall フック
# アプリケーションのインストール前に実行される

set -e

echo "$(date): BeforeInstall hook started"

# ログディレクトリの作成
LOG_DIR="/var/log/cicd-comparison-api"
mkdir -p "$LOG_DIR"
chown ec2-user:ec2-user "$LOG_DIR"

# アプリケーションディレクトリの準備
APP_DIR="/opt/cicd-comparison-api"
if [ -d "$APP_DIR" ]; then
    echo "Backing up existing application..."
    BACKUP_DIR="/opt/cicd-comparison-api-backup-$(date +%Y%m%d-%H%M%S)"
    mv "$APP_DIR" "$BACKUP_DIR"
    echo "Backup created at: $BACKUP_DIR"
fi

# 新しいアプリケーションディレクトリを作成
mkdir -p "$APP_DIR"
chown ec2-user:ec2-user "$APP_DIR"

# 必要なシステムパッケージの確認・インストール
echo "Checking system dependencies..."

# Python 3.13の確認
if ! command -v python3.13 &> /dev/null; then
    echo "Installing Python 3.13..."
    # Amazon Linux 2023の場合
    if [ -f /etc/amazon-linux-release ]; then
        dnf install -y python3.13 python3.13-pip
    # Ubuntu/Debianの場合
    elif [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y python3.13 python3.13-venv python3.13-dev
    fi
fi

# uvの確認・インストール
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# systemdサービスファイルの準備
echo "Preparing systemd service..."
cat > /etc/systemd/system/cicd-comparison-api.service << 'EOF'
[Unit]
Description=CI/CD Comparison FastAPI Application
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/cicd-comparison-api/modules/api
Environment=PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/opt/cicd-comparison-api/modules/api
Environment=ENVIRONMENT=local
Environment=LOG_LEVEL=INFO
ExecStart=/home/ec2-user/.local/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# systemdの設定をリロード
systemctl daemon-reload

echo "$(date): BeforeInstall hook completed successfully"
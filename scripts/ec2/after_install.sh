#!/bin/bash

# EC2 CodeDeploy - AfterInstall フック
# アプリケーションのインストール後に実行される

set -e

echo "$(date): AfterInstall hook started"

APP_DIR="/opt/cicd-comparison-api"
API_DIR="$APP_DIR/modules/api"

# アプリケーションディレクトリに移動
cd "$APP_DIR"

# 権限の設定
echo "Setting up permissions..."
chown -R ec2-user:ec2-user "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} \;
find "$APP_DIR" -type f -exec chmod 644 {} \;
find "$APP_DIR/scripts" -name "*.sh" -exec chmod 755 {} \;

# Python仮想環境の作成とパッケージインストール
echo "Setting up Python environment..."
cd "$API_DIR"

# ec2-userとして実行
sudo -u ec2-user bash << 'EOF'
set -e

# uvを使用して依存関係をインストール
export PATH="$HOME/.cargo/bin:$PATH"

# プロジェクトの初期化
if [ ! -f "pyproject.toml" ]; then
    uv init --no-readme --python 3.13
fi

# 依存関係のインストール
if [ -f "requirements.txt" ]; then
    uv add $(cat requirements.txt | grep -v "^#" | grep -v "^$" | tr '\n' ' ')
fi

# 仮想環境の作成
uv venv --python 3.13

# 依存関係の同期
uv sync

echo "Python environment setup completed"
EOF

# ログローテーション設定
echo "Setting up log rotation..."
cat > /etc/logrotate.d/cicd-comparison-api << 'EOF'
/var/log/cicd-comparison-api/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 ec2-user ec2-user
    postrotate
        systemctl reload cicd-comparison-api || true
    endscript
}
EOF

# ヘルスチェック用スクリプトの作成
echo "Creating health check script..."
cat > "$APP_DIR/health_check.sh" << 'EOF'
#!/bin/bash

# ヘルスチェックスクリプト
HEALTH_URL="http://localhost:8000/health"
MAX_RETRIES=5
RETRY_INTERVAL=2

for i in $(seq 1 $MAX_RETRIES); do
    if curl -f -s "$HEALTH_URL" > /dev/null 2>&1; then
        echo "Health check passed"
        exit 0
    fi
    
    echo "Health check attempt $i failed, retrying in $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
done

echo "Health check failed after $MAX_RETRIES attempts"
exit 1
EOF

chmod +x "$APP_DIR/health_check.sh"

echo "$(date): AfterInstall hook completed successfully"
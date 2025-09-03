#!/bin/bash

# CodePipeline専用 EC2インスタンス初期化スクリプト
# CI/CD比較プロジェクト用

set -e

# ログ出力設定
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting CodePipeline user-data script execution at $(date)"

# 環境変数設定
export CICD_TOOL="codepipeline"
export ENVIRONMENT="local"
export APP_NAME="CodePipeline CI/CD Comparison API"

# システム更新
echo "Updating system packages..."
yum update -y

# 必要なパッケージのインストール
echo "Installing required packages..."
yum install -y ruby wget curl jq python3 python3-pip amazon-cloudwatch-agent bc

# CodeDeployエージェントのインストール
echo "Installing CodeDeploy agent..."
cd /home/ec2-user
wget https://aws-codedeploy-ap-northeast-1.s3.ap-northeast-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl enable codedeploy-agent
systemctl start codedeploy-agent

# Python環境のセットアップ
echo "Setting up Python environment..."
pip3 install --upgrade pip

# uvのインストール
echo "Installing uv package manager..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="/root/.cargo/bin:$PATH"

# アプリケーション用ディレクトリ作成
echo "Creating CodePipeline application directories..."
mkdir -p /opt/codepipeline-local-api
mkdir -p /opt/codepipeline-local-api/logs
mkdir -p /var/log/codepipeline-local-api
chown -R ec2-user:ec2-user /opt/codepipeline-local-api
chown -R ec2-user:ec2-user /var/log/codepipeline-local-api

# インスタンスIDを環境変数として設定
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "export INSTANCE_ID=$INSTANCE_ID" >> /etc/environment
echo "export CICD_TOOL=$CICD_TOOL" >> /etc/environment
echo "export ENVIRONMENT=$ENVIRONMENT" >> /etc/environment

# CloudWatchエージェント設定ファイル作成（CodePipeline専用）
echo "Configuring CloudWatch agent for CodePipeline..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/codepipeline-local-api/application.log",
            "log_group_name": "/aws/ec2/codepipeline-local-api",
            "log_stream_name": "{instance_id}/application",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/codepipeline-local-system",
            "log_stream_name": "{instance_id}/system",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/codedeploy-agent/codedeploy-agent.log",
            "log_group_name": "/aws/ec2/codepipeline-local-codedeploy",
            "log_stream_name": "{instance_id}/codedeploy-agent",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "cicd/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# CloudWatchエージェント開始
echo "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# CodePipeline専用のプレースホルダーアプリ作成
echo "Creating CodePipeline placeholder FastAPI application..."
cat > /opt/codepipeline-local-api/main.py << 'EOF'
from fastapi import FastAPI, Request
import uvicorn
import datetime
import os
import logging
import json
from logging.handlers import RotatingFileHandler

# ログ設定
log_formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

file_handler = RotatingFileHandler(
    "/var/log/codepipeline-local-api/application.log",
    maxBytes=10*1024*1024,  # 10MB
    backupCount=5
)
file_handler.setFormatter(log_formatter)
file_handler.setLevel(logging.INFO)

logger = logging.getLogger("codepipeline_fastapi_app")
logger.setLevel(logging.INFO)
logger.addHandler(file_handler)

app = FastAPI(
    title="CodePipeline CI/CD Comparison API", 
    version="1.0.0",
    description="CodePipeline専用のCI/CD比較API"
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = datetime.datetime.utcnow()
    response = await call_next(request)
    process_time = (datetime.datetime.utcnow() - start_time).total_seconds()
    
    log_data = {
        "method": request.method,
        "url": str(request.url),
        "status_code": response.status_code,
        "process_time": process_time,
        "client_ip": request.client.host if request.client else "unknown",
        "cicd_tool": "codepipeline"
    }
    logger.info(f"Request processed: {json.dumps(log_data)}")
    return response

@app.get("/health")
def health():
    logger.info("Health check requested")
    return {
        "status": "healthy",
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "instance_id": os.environ.get("INSTANCE_ID", "unknown"),
        "deployment_target": "ec2",
        "cicd_tool": "codepipeline",
        "port": 8082
    }

@app.get("/version")
def version():
    logger.info("Version info requested")
    return {
        "version": "1.0.0",
        "build_time": datetime.datetime.utcnow().isoformat(),
        "commit_hash": "placeholder",
        "deployment_target": "ec2",
        "cicd_tool": "codepipeline"
    }

@app.get("/api/items")
def get_items():
    logger.info("Items list requested")
    return [
        {
            "id": 1,
            "name": "CodePipeline EC2 Sample Item",
            "description": "This is a sample item from CodePipeline EC2 deployment",
            "created_at": datetime.datetime.utcnow().isoformat(),
            "cicd_tool": "codepipeline"
        }
    ]

@app.post("/api/items")
def create_item(item: dict):
    logger.info(f"Item creation requested: {item}")
    return {
        "id": 2,
        "name": item.get("name", "New CodePipeline Item"),
        "description": item.get("description", "New item from CodePipeline"),
        "created_at": datetime.datetime.utcnow().isoformat(),
        "cicd_tool": "codepipeline"
    }

@app.get("/api/items/{item_id}")
def get_item(item_id: int):
    logger.info(f"Item {item_id} requested")
    return {
        "id": item_id,
        "name": f"CodePipeline EC2 Item {item_id}",
        "description": f"This is item {item_id} from CodePipeline EC2 deployment",
        "created_at": datetime.datetime.utcnow().isoformat(),
        "cicd_tool": "codepipeline"
    }

if __name__ == "__main__":
    logger.info("Starting CodePipeline FastAPI application on EC2")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
EOF

# systemdサービス作成（CodePipeline専用）
echo "Creating CodePipeline systemd service..."
cat > /etc/systemd/system/codepipeline-local-api.service << 'EOF'
[Unit]
Description=CodePipeline FastAPI Application for CI/CD Comparison
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/codepipeline-local-api
Environment=INSTANCE_ID=%i
Environment=CICD_TOOL=codepipeline
Environment=ENVIRONMENT=local
ExecStart=/usr/local/bin/python3 main.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 権限設定
chown ec2-user:ec2-user /opt/codepipeline-local-api/main.py

# サービス有効化と開始
echo "Enabling and starting CodePipeline FastAPI service..."
systemctl daemon-reload
systemctl enable codepipeline-local-api
systemctl start codepipeline-local-api

# サービス状態確認
echo "Checking CodePipeline service status..."
systemctl status codepipeline-local-api --no-pager

# ヘルスチェック
echo "Performing initial health check..."
sleep 10
curl -f http://localhost:8000/health || echo "Health check failed"

echo "CodePipeline user-data script execution completed at $(date)"
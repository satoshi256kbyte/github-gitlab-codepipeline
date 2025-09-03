# トラブルシューティングガイド

このドキュメントでは、CI/CDパイプライン比較プロジェクトで発生する可能性のある問題と、その解決方法について詳しく説明します。

## 📋 目次

- [一般的な問題](#一般的な問題)
- [GitHub Actions関連](#github-actions関連)
- [GitLab CI/CD関連](#gitlab-cicd関連)
- [CodePipeline関連](#codepipeline関連)
- [AWS インフラ関連](#awsインフラ関連)
- [アプリケーション関連](#アプリケーション関連)
- [ローカル開発関連](#ローカル開発関連)
- [デバッグツール](#デバッグツール)

## 🔧 一般的な問題

### 1. 環境設定問題

#### Python環境の問題

**症状**: `python: command not found` または `uv: command not found`

**解決方法**:

```bash
# asdfでPythonをインストール
asdf install python 3.13.0
asdf global python 3.13.0

# uvのインストール
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc  # または ~/.zshrc

# 環境確認
python --version
uv --version
```

#### AWS認証問題

**症状**: `Unable to locate credentials`

**解決方法**:

```bash
# AWS認証情報の設定
aws configure

# または環境変数で設定
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=ap-northeast-1

# 認証確認
aws sts get-caller-identity
```

#### Docker関連問題

**症状**: `Cannot connect to the Docker daemon`

**解決方法**:

```bash
# Dockerデーモンの起動確認
docker info

# macOS: Docker Desktopの起動
open -a Docker

# Linux: Dockerサービスの起動
sudo systemctl start docker
sudo systemctl enable docker

# ユーザーをdockerグループに追加（Linux）
sudo usermod -aG docker $USER
newgrp docker
```

### 2. 依存関係問題

#### Node.js/npm関連

**症状**: `npm: command not found` または CDK関連エラー

**解決方法**:

```bash
# Node.jsのインストール（asdf使用）
asdf install nodejs 18.17.0
asdf global nodejs 18.17.0

# CDK依存関係のインストール
cd cdk
npm install

# CDKの確認
npx cdk --version
```

#### Python依存関係

**症状**: `ModuleNotFoundError` または パッケージ関連エラー

**解決方法**:

```bash
# 仮想環境の再作成
uv venv --python 3.13
source .venv/bin/activate  # Linux/macOS
# または .venv\Scripts\activate  # Windows

# 依存関係の再インストール
uv sync --dev

# 特定パッケージの問題
uv add package-name
uv remove package-name
```

## 🐙 GitHub Actions関連

### 1. ワークフロー実行エラー

#### OIDC認証失敗

**症状**: `Error: Could not assume role with OIDC`

**解決方法**:

```bash
# IAMロールの確認
aws iam get-role --role-name github-actions-role

# トラストポリシーの確認
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument'

# 正しいトラストポリシーの設定
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name github-actions-role \
  --policy-document file://trust-policy.json
```

#### Secrets設定問題

**症状**: `Secret not found` または認証エラー

**解決方法**:

```bash
# GitHub Secretsの確認（GitHub UI）
# Repository > Settings > Secrets and variables > Actions

# 必要なSecrets:
# - AWS_ACCOUNT_ID
# - AWS_REGION
# - GITHUB_TOKEN (自動生成、通常は不要)

# Secretsの値確認（デバッグ用）
echo "AWS Account: ${{ secrets.AWS_ACCOUNT_ID }}"
echo "AWS Region: ${{ secrets.AWS_REGION }}"
```

#### アクション実行失敗

**症状**: 特定のアクションでエラーが発生

**解決方法**:

```yaml
# デバッグ情報の追加
- name: Debug information
  run: |
    echo "Runner OS: ${{ runner.os }}"
    echo "GitHub Event: ${{ github.event_name }}"
    echo "GitHub Ref: ${{ github.ref }}"
    env

# アクションのバージョン固定
- uses: actions/checkout@v4  # 最新の安定版を使用
- uses: actions/setup-python@v4
  with:
    python-version: '3.13'

# タイムアウト設定
- name: Long running task
  run: ./long-task.sh
  timeout-minutes: 30
```

### 2. ローカルテスト（act）問題

#### act実行エラー

**症状**: `act` コマンドでエラーが発生

**解決方法**:

```bash
# actの最新版インストール
brew upgrade act

# 設定ファイルの確認
cat .actrc

# プラットフォーム指定での実行
act --platform ubuntu-latest=catthehacker/ubuntu:act-latest

# 詳細ログでの実行
act -v

# 特定のジョブのみ実行
act -j test

# ドライランモード
act --dryrun
```

## 🦊 GitLab CI/CD関連

### 1. パイプライン実行エラー

#### 変数設定問題

**症状**: `AWS credentials not found` または環境変数エラー

**解決方法**:

```bash
# GitLab CI/CD変数の設定確認
# Project > Settings > CI/CD > Variables

# 必要な変数:
# AWS_ACCESS_KEY_ID (Protected: Yes, Masked: Yes)
# AWS_SECRET_ACCESS_KEY (Protected: Yes, Masked: Yes)
# AWS_DEFAULT_REGION (Protected: No, Masked: No)
# AWS_ACCOUNT_ID (Protected: No, Masked: No)

# 変数のスコープ確認
# - Project level (推奨)
# - Group level
# - Instance level
```

#### Runner関連問題

**症状**: `This job is stuck because you don't have any active runners`

**解決方法**:

```bash
# 共有Runnerの有効化確認
# Project > Settings > CI/CD > Runners
# "Enable shared runners for this project" をチェック

# セルフホストRunnerの設定
gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token $REGISTRATION_TOKEN \
  --executor docker \
  --docker-image python:3.13

# Runnerの状態確認
gitlab-runner list
gitlab-runner verify
```

#### Docker関連エラー

**症状**: `Cannot connect to the Docker daemon` (GitLab Runner)

**解決方法**:

```yaml
# .gitlab-ci.yml でのDocker設定
variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""

services:
  - docker:dind

before_script:
  - docker info

# または特権モードの使用
test:
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_DRIVER: overlay2
  script:
    - docker build -t test-image .
```

### 2. ローカルテスト（GitLab Runner）問題

#### GitLab Runner設定エラー

**症状**: `ERROR: Preparation failed`

**解決方法**:

```bash
# 設定ファイルの確認
cat .gitlab-runner/config.toml

# Runnerの再登録
gitlab-runner unregister --all-runners
gitlab-runner register --config .gitlab-runner/config.toml

# Docker executorの確認
docker pull python:3.13
gitlab-runner exec docker --docker-image python:3.13 test

# 詳細ログでの実行
gitlab-runner --debug exec docker test
```

## ☁️ CodePipeline関連

### 1. パイプライン実行エラー

#### ソース設定問題

**症状**: `Source action failed` または GitHub連携エラー

**解決方法**:

```bash
# GitHub Personal Access Tokenの確認
aws secretsmanager get-secret-value --secret-id github-token

# トークンの権限確認（必要なスコープ）
# - repo (Full control of private repositories)
# - admin:repo_hook (Full control of repository hooks)

# 新しいトークンの設定
aws secretsmanager update-secret \
  --secret-id github-token \
  --secret-string "ghp_new_token_here"

# CodePipelineの再実行
aws codepipeline start-pipeline-execution \
  --name codepipeline-local-pipeline
```

#### CodeBuild実行エラー

**症状**: CodeBuildプロジェクトでビルド失敗

**解決方法**:

```bash
# CodeBuildログの確認
aws logs tail /aws/codebuild/codepipeline-local-lint-build --follow

# buildspecファイルの検証
python -c "import yaml; yaml.safe_load(open('cicd/buildspecs/lint.yml'))"

# 環境変数の確認
aws codebuild batch-get-projects \
  --names codepipeline-local-lint-build \
  --query 'projects[0].environment.environmentVariables'

# buildspecのローカルテスト
docker run --rm -it \
  -v $(pwd):/workspace \
  -w /workspace \
  aws/codebuild/standard:5.0 \
  bash -c "bash cicd/buildspecs/common_install.sh && bash cicd/buildspecs/lint.yml"
```

#### IAMロール権限問題

**症状**: `Access Denied` エラー

**解決方法**:

```bash
# CodePipelineサービスロールの確認
aws iam get-role --role-name codepipeline-service-role

# 必要な権限の確認
aws iam list-attached-role-policies --role-name codepipeline-service-role

# CodeBuildサービスロールの確認
aws iam get-role --role-name codebuild-service-role

# 権限の追加（必要に応じて）
aws iam attach-role-policy \
  --role-name codepipeline-service-role \
  --policy-arn arn:aws:iam::aws:policy/AWSCodePipelineFullAccess
```

## 🏗️ AWS インフラ関連

### 1. CDKデプロイエラー

#### ブートストラップ問題

**症状**: `This stack uses assets, so the toolkit stack must be deployed`

**解決方法**:

```bash
# CDKブートストラップの実行
cd cdk
npx cdk bootstrap

# 特定のリージョンでのブートストラップ
npx cdk bootstrap aws://123456789012/ap-northeast-1

# ブートストラップ状態の確認
aws cloudformation describe-stacks --stack-name CDKToolkit
```

#### スタックデプロイ失敗

**症状**: `CREATE_FAILED` または `UPDATE_FAILED`

**解決方法**:

```bash
# スタック状態の確認
aws cloudformation describe-stacks --stack-name NetworkStack

# スタックイベントの確認
aws cloudformation describe-stack-events --stack-name NetworkStack

# リソース制限の確認
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A  # Running On-Demand EC2 instances

# 失敗したスタックの削除
npx cdk destroy NetworkStack --force

# 再デプロイ
npx cdk deploy NetworkStack
```

#### リソース競合問題

**症状**: `Resource already exists` エラー

**解決方法**:

```bash
# 既存リソースの確認
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=shared-local-vpc"

# リソースの手動削除（注意して実行）
aws ec2 delete-vpc --vpc-id vpc-xxxxxxxxx

# CDKでの差分確認
npx cdk diff

# 強制的な再作成
npx cdk deploy --force
```

### 2. ALB/ECS/EC2関連問題

#### ALBヘルスチェック失敗

**症状**: `Target health check failed`

**解決方法**:

```bash
# ターゲットグループの状態確認
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:targetgroup/github-local-ecs-tg/1234567890123456

# セキュリティグループの確認
aws ec2 describe-security-groups \
  --group-names github-local-ecs-sg

# ECSタスクの状態確認
aws ecs describe-tasks \
  --cluster github-local-ecs-cluster \
  --tasks $(aws ecs list-tasks --cluster github-local-ecs-cluster --query 'taskArns[0]' --output text)

# アプリケーションログの確認
aws logs tail /ecs/github-local-ecs-api --follow
```

#### ECSタスク起動失敗

**症状**: `Task failed to start`

**解決方法**:

```bash
# タスク定義の確認
aws ecs describe-task-definition --task-definition github-local-ecs-task

# サービスイベントの確認
aws ecs describe-services \
  --cluster github-local-ecs-cluster \
  --services github-local-ecs-service \
  --query 'services[0].events[0:5]'

# ECRイメージの確認
aws ecr describe-images \
  --repository-name github-local-ecs-repo

# タスクの手動実行
aws ecs run-task \
  --cluster github-local-ecs-cluster \
  --task-definition github-local-ecs-task \
  --launch-type FARGATE \
  --network-configuration 'awsvpcConfiguration={subnets=[subnet-xxxxxxxxx],securityGroups=[sg-xxxxxxxxx],assignPublicIp=ENABLED}'
```

#### EC2インスタンス問題

**症状**: EC2インスタンスが起動しない、またはアプリケーションにアクセスできない

**解決方法**:

```bash
# インスタンス状態の確認
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=github-local-ec2-instance"

# インスタンスログの確認
aws ec2 get-console-output --instance-id i-xxxxxxxxx

# SSMでのインスタンス接続
aws ssm start-session --target i-xxxxxxxxx

# CodeDeployエージェントの状態確認
sudo service codedeploy-agent status
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log

# アプリケーションの状態確認
sudo systemctl status myapp
sudo journalctl -u myapp -f
```

## 📱 アプリケーション関連

### 1. FastAPI関連問題

#### アプリケーション起動エラー

**症状**: `ModuleNotFoundError` または起動失敗

**解決方法**:

```bash
# 依存関係の確認
cd modules/api
uv sync

# アプリケーションの直接実行
uv run python -m uvicorn main:app --host 0.0.0.0 --port 8000

# デバッグモードでの実行
uv run python -m uvicorn main:app --reload --log-level debug

# 環境変数の確認
export DEBUG=true
export LOG_LEVEL=DEBUG
uv run python -c "from main import app; print(app)"
```

#### API エンドポイントエラー

**症状**: `404 Not Found` または `500 Internal Server Error`

**解決方法**:

```bash
# エンドポイントの確認
curl -v http://localhost:8000/health
curl -v http://localhost:8000/docs

# ログの確認
tail -f logs/app.log

# テストの実行
uv run pytest modules/api/tests/ -v

# 特定のテストの実行
uv run pytest modules/api/tests/test_main.py::test_health_check -v -s
```

### 2. Docker関連問題

#### イメージビルド失敗

**症状**: `docker build` でエラー

**解決方法**:

```bash
# Dockerfileの確認
cat modules/api/Dockerfile

# ビルドコンテキストの確認
docker build --no-cache -t myapp:latest modules/api/

# マルチステージビルドのデバッグ
docker build --target development -t myapp:dev modules/api/

# ビルドログの詳細確認
docker build --progress=plain -t myapp:latest modules/api/
```

#### コンテナ実行エラー

**症状**: コンテナが起動しない、または異常終了

**解決方法**:

```bash
# コンテナログの確認
docker logs container-id

# インタラクティブモードでの実行
docker run -it --rm myapp:latest /bin/bash

# 環境変数の確認
docker run --rm myapp:latest env

# ポートマッピングの確認
docker run -p 8000:8000 myapp:latest

# ヘルスチェックの追加
docker run --health-cmd="curl -f http://localhost:8000/health || exit 1" \
           --health-interval=30s \
           --health-timeout=10s \
           --health-retries=3 \
           myapp:latest
```

## 💻 ローカル開発関連

### 1. 開発環境問題

#### 仮想環境の問題

**症状**: パッケージが見つからない、または競合

**解決方法**:

```bash
# 仮想環境の再作成
rm -rf .venv
uv venv --python 3.13
source .venv/bin/activate

# 依存関係の再インストール
uv sync --dev

# 特定パッケージの問題解決
uv add --dev pytest
uv remove problematic-package
uv add problematic-package@latest
```

#### ポート競合問題

**症状**: `Address already in use`

**解決方法**:

```bash
# ポート使用状況の確認
lsof -i :8000
netstat -tulpn | grep :8000

# プロセスの終了
kill -9 $(lsof -t -i:8000)

# 別のポートでの起動
uv run uvicorn main:app --port 8001

# 環境変数での設定
export PORT=8001
uv run uvicorn main:app --host 0.0.0.0 --port $PORT
```

### 2. テスト関連問題

#### テスト実行エラー

**症状**: `pytest` でテストが失敗

**解決方法**:

```bash
# テスト環境の確認
uv run pytest --version
uv run pytest --collect-only

# 詳細ログでのテスト実行
uv run pytest -v -s

# 特定のテストファイルのみ実行
uv run pytest modules/api/tests/test_main.py -v

# デバッグモードでのテスト実行
uv run pytest --pdb

# カバレッジ付きテスト
uv run pytest --cov=modules/api --cov-report=html
```

#### テストデータベース問題

**症状**: テスト用データベースの問題

**解決方法**:

```bash
# テスト用設定の確認
cat modules/api/tests/conftest.py

# テストデータベースの初期化
uv run pytest --setup-only

# テスト分離の確認
uv run pytest --setup-show

# 並列テスト実行の問題
uv run pytest -n auto  # pytest-xdist使用時
```

## 🛠️ デバッグツール

### 1. ログ収集スクリプト

```bash
#!/bin/bash
# scripts/collect-debug-info.sh

echo "=== System Information ==="
uname -a
python --version
uv --version
docker --version
aws --version

echo "=== AWS Configuration ==="
aws configure list
aws sts get-caller-identity

echo "=== Project Status ==="
git status
git log --oneline -5

echo "=== Environment Variables ==="
env | grep -E "(AWS|GITHUB|GITLAB)" | sort

echo "=== Running Processes ==="
ps aux | grep -E "(python|docker|node)"

echo "=== Network Status ==="
netstat -tulpn | grep -E "(8000|8080|8081|8082)"

echo "=== Disk Usage ==="
df -h
du -sh .venv node_modules 2>/dev/null || true
```

### 2. ヘルスチェックスクリプト

```bash
#!/bin/bash
# scripts/health-check.sh

check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "Checking $name... "
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null); then
        if [ "$response" = "$expected_status" ]; then
            echo "✅ OK ($response)"
            return 0
        else
            echo "❌ FAIL ($response)"
            return 1
        fi
    else
        echo "❌ UNREACHABLE"
        return 1
    fi
}

echo "=== Health Check Report ==="

# ローカル開発サーバー
check_service "Local Dev Server" "http://localhost:8000/health"

# GitHub Actions専用エンドポイント
check_service "GitHub Lambda" "https://github-local-api-gateway.execute-api.ap-northeast-1.amazonaws.com/prod/health"
check_service "GitHub ECS" "http://github-local-ecs-alb.ap-northeast-1.elb.amazonaws.com:8080/health"
check_service "GitHub EC2" "http://github-local-ec2-alb.ap-northeast-1.elb.amazonaws.com:8080/health"

# GitLab CI/CD専用エンドポイント
check_service "GitLab Lambda" "https://gitlab-local-api-gateway.execute-api.ap-northeast-1.amazonaws.com/prod/health"
check_service "GitLab ECS" "http://gitlab-local-ecs-alb.ap-northeast-1.elb.amazonaws.com:8081/health"
check_service "GitLab EC2" "http://gitlab-local-ec2-alb.ap-northeast-1.elb.amazonaws.com:8081/health"

# CodePipeline専用エンドポイント
check_service "CodePipeline Lambda" "https://codepipeline-local-api-gateway.execute-api.ap-northeast-1.amazonaws.com/prod/health"
check_service "CodePipeline ECS" "http://codepipeline-local-ecs-alb.ap-northeast-1.elb.amazonaws.com:8082/health"
check_service "CodePipeline EC2" "http://codepipeline-local-ec2-alb.ap-northeast-1.elb.amazonaws.com:8082/health"

echo "=== Health Check Complete ==="
```

### 3. 自動修復スクリプト

```bash
#!/bin/bash
# scripts/auto-fix.sh

fix_python_env() {
    echo "🔧 Fixing Python environment..."
    rm -rf .venv
    uv venv --python 3.13
    source .venv/bin/activate
    uv sync --dev
    echo "✅ Python environment fixed"
}

fix_docker_issues() {
    echo "🔧 Fixing Docker issues..."
    docker system prune -f
    docker pull python:3.13
    docker pull catthehacker/ubuntu:act-latest
    echo "✅ Docker issues fixed"
}

fix_aws_config() {
    echo "🔧 Checking AWS configuration..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "❌ AWS credentials not configured"
        echo "Please run: aws configure"
        return 1
    fi
    echo "✅ AWS configuration OK"
}

fix_node_env() {
    echo "🔧 Fixing Node.js environment..."
    cd cdk
    rm -rf node_modules package-lock.json
    npm install
    cd ..
    echo "✅ Node.js environment fixed"
}

case "${1:-all}" in
    python)
        fix_python_env
        ;;
    docker)
        fix_docker_issues
        ;;
    aws)
        fix_aws_config
        ;;
    node)
        fix_node_env
        ;;
    all)
        fix_python_env
        fix_docker_issues
        fix_aws_config
        fix_node_env
        ;;
    *)
        echo "Usage: $0 [python|docker|aws|node|all]"
        exit 1
        ;;
esac
```

---

このトラブルシューティングガイドを参考に、発生した問題を迅速に解決してください。問題が解決しない場合は、デバッグ情報を収集してIssueを作成することをお勧めします。

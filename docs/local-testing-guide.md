# ローカルテスト環境構築ガイド

このドキュメントでは、GitHub Actions、GitLab CI/CD、AWS CodePipelineのパイプラインをローカル環境でテストする方法について説明します。

## 📋 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [GitHub Actionsローカルテスト](#github-actionsローカルテスト)
- [GitLab CI/CDローカルテスト](#gitlab-cicdローカルテスト)
- [CodePipelineローカルテスト](#codepipelineローカルテスト)
- [統合テスト](#統合テスト)
- [トラブルシューティング](#トラブルシューティング)

## 🎯 概要

ローカルテスト環境を構築することで、以下のメリットがあります：

- **高速フィードバック**: クラウド環境にデプロイする前に問題を発見
- **コスト削減**: AWSリソースの使用量を削減
- **デバッグ効率**: ローカルでのステップ実行とデバッグ
- **オフライン開発**: インターネット接続が不安定な環境での開発

## 🔧 前提条件

### 必要なツール

| ツール | バージョン | 用途 | インストール方法 |
|--------|-----------|------|-----------------|
| [act](https://github.com/nektos/act) | latest | GitHub Actionsローカル実行 | `brew install act` |
| [GitLab Runner](https://docs.gitlab.com/runner/) | latest | GitLab CI/CDローカル実行 | `brew install gitlab-runner` |
| [Docker](https://www.docker.com/) | latest | コンテナ実行環境 | Docker Desktop |
| [LocalStack](https://localstack.cloud/) | latest | AWSサービスエミュレーション | `pip install localstack` |

### 基本設定

```bash
# プロジェクトルートに移動
cd /path/to/github-gitlab-codepipeline

# 必要なツールのインストール確認
act --version
gitlab-runner --version
docker --version
localstack --version
```

## 🐙 GitHub Actionsローカルテスト

### 1. actツールの設定

#### インストール

```bash
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Windows (Chocolatey)
choco install act-cli
```

#### 設定ファイル

`.actrc` ファイルが既に作成されています：

```bash
# .actrc の内容確認
cat .actrc
```

```ini
# GitHub Actions用のローカル実行設定
--container-architecture linux/amd64
--platform ubuntu-latest=catthehacker/ubuntu:act-latest
--platform ubuntu-22.04=catthehacker/ubuntu:act-22.04
--platform ubuntu-20.04=catthehacker/ubuntu:act-20.04

# リソース制限
--container-cap-add SYS_PTRACE
--container-cap-add NET_ADMIN

# 環境変数ファイル
--env-file .env.local

# ボリュームマウント
--bind
```

#### 環境変数設定

```bash
# .env.local ファイルの作成（既存の場合は確認）
cat > .env.local << 'EOF'
# AWS設定（ローカルテスト用）
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012

# GitHub設定
GITHUB_TOKEN=ghp_test_token
GITHUB_REPOSITORY=test/repo

# アプリケーション設定
ENVIRONMENT=local
DEBUG=true
LOG_LEVEL=DEBUG
EOF
```

### 2. ワークフローのローカル実行

#### 全ワークフローの実行

```bash
# 全ジョブの実行
act

# 特定のイベントでの実行
act push
act pull_request
```

#### 特定ジョブの実行

```bash
# 静的解析ジョブのみ実行
act -j lint

# ユニットテストジョブのみ実行
act -j test

# SCAチェックジョブのみ実行
act -j sca

# SASTチェックジョブのみ実行
act -j sast

# デプロイジョブのみ実行（Lambda）
act -j deploy_lambda

# デプロイジョブのみ実行（ECS）
act -j deploy-ecs

# デプロイジョブのみ実行（EC2）
act -j deploy_ec2
```

#### デバッグモード

```bash
# 詳細ログ付きで実行
act -v

# ドライランモード（実際には実行しない）
act --dryrun

# 特定のステップで停止
act --step-by-step

# インタラクティブモード
act -i
```

### 3. GitHub Actions固有のテスト

```bash
# ワークフロー構文チェック
act --list

# 使用可能なイベント確認
act --help | grep -A 20 "Event types"

# シークレット使用のテスト
act --secret-file .secrets

# マトリックス戦略のテスト
act -j test --matrix python-version:3.13
```

## 🦊 GitLab CI/CDローカルテスト

### 1. GitLab Runnerの設定

#### インストール

```bash
# macOS
brew install gitlab-runner

# Linux
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# Docker版
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

#### 設定ファイル

`.gitlab-runner/config.toml` ファイルが既に作成されています：

```bash
# 設定ファイルの確認
cat .gitlab-runner/config.toml
```

```toml
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "local-docker-runner"
  url = "https://gitlab.com/"
  token = "local-test-token"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "python:3.13"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
```

### 2. パイプラインのローカル実行

#### 全パイプラインの実行

```bash
# Docker executorでの実行
gitlab-runner exec docker cache

# 特定のステージの実行
gitlab-runner exec docker lint
gitlab-runner exec docker test
gitlab-runner exec docker sca
gitlab-runner exec docker sast
gitlab-runner exec docker deploy_lambda
gitlab-runner exec docker deploy-ecs
gitlab-runner exec docker deploy_ec2
```

#### 環境変数の設定

```bash
# 環境変数ファイルの作成
cat > .gitlab-ci-env << 'EOF'
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012
ENVIRONMENT=local
DEBUG=true
EOF

# 環境変数を使用した実行
gitlab-runner exec docker --env-file .gitlab-ci-env test
```

#### カスタム設定での実行

```bash
# カスタム設定ファイルを使用
gitlab-runner --config .gitlab-runner/config.toml exec docker test

# 特定のDockerイメージを使用
gitlab-runner exec docker --docker-image python:3.13-slim test

# ボリュームマウント付きで実行
gitlab-runner exec docker --docker-volumes /tmp:/tmp test
```

### 3. GitLab CI/CD固有のテスト

```bash
# パイプライン構文チェック
# GitLab CI Lintツールを使用（要GitLabアカウント）
curl --header "Content-Type: application/json" \
     --data '{"content": "$(cat .gitlab-ci.yml)"}' \
     "https://gitlab.com/api/v4/ci/lint"

# ローカルでのYAML構文チェック
python -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"

# 依存関係の確認
gitlab-runner exec docker --help | grep -A 10 "docker"
```

## ☁️ CodePipelineローカルテスト

### 1. CodeBuildローカル実行

#### CodeBuild Agentの設定

```bash
# CodeBuild Agentのダウンロード
git clone https://github.com/aws/aws-codebuild-docker-images.git
cd aws-codebuild-docker-images/ubuntu/standard/5.0

# Dockerイメージのビルド
docker build -t aws/codebuild/standard:5.0 .
```

#### buildspecファイルのローカル実行

```bash
# 各buildspecファイルの実行
docker run --rm -it \
  -v $(pwd):/workspace \
  -w /workspace \
  aws/codebuild/standard:5.0 \
  bash -c "
    source cicd/buildspecs/common_install.sh &&
    source cicd/buildspecs/common_pre_build.sh &&
    bash cicd/buildspecs/lint.yml
  "

# 特定のbuildspecファイルのテスト
for buildspec in cicd/buildspecs/*.yml; do
  echo "Testing $buildspec..."
  docker run --rm -it \
    -v $(pwd):/workspace \
    -w /workspace \
    -e AWS_DEFAULT_REGION=ap-northeast-1 \
    -e AWS_ACCOUNT_ID=123456789012 \
    aws/codebuild/standard:5.0 \
    bash -c "
      if [ -f cicd/buildspecs/common_install.sh ]; then
        bash cicd/buildspecs/common_install.sh
      fi &&
      if [ -f cicd/buildspecs/common_pre_build.sh ]; then
        bash cicd/buildspecs/common_pre_build.sh
      fi &&
      # buildspecファイルの内容を実行
      echo 'Simulating buildspec execution for $buildspec'
    "
done
```

### 2. LocalStackを使用したAWSサービスエミュレーション

#### LocalStackの起動

```bash
# LocalStackのインストール
pip install localstack

# LocalStackの起動
localstack start -d

# サービスの確認
localstack status services
```

#### LocalStack設定

```bash
# AWS CLIをLocalStackに向ける
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=ap-northeast-1

# S3バケットの作成（テスト用）
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket

# CodeBuildプロジェクトの作成（テスト用）
aws --endpoint-url=http://localhost:4566 codebuild create-project \
  --name test-project \
  --source type=GITHUB,location=https://github.com/test/repo \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_SMALL \
  --service-role arn:aws:iam::123456789012:role/service-role/codebuild-test-service-role
```

### 3. buildspecファイルの個別テスト

```bash
# 静的解析buildspecのテスト
./scripts/test-buildspec.sh cicd/buildspecs/lint.yml

# ユニットテストbuildspecのテスト
./scripts/test-buildspec.sh cicd/buildspecs/test.yml

# SCAチェックbuildspecのテスト
./scripts/test-buildspec.sh cicd/buildspecs/sca.yml

# SASTチェックbuildspecのテスト
./scripts/test-buildspec.sh cicd/buildspecs/sast.yml
```

## 🧪 統合テスト

### 1. 全CI/CDツールの統合テスト

```bash
# 統合テストスクリプトの実行
./scripts/run-integration-tests.sh

# ローカル��境での統合テスト
./scripts/run-integration-tests.sh --local-mode

# 特定のツールのみテスト
./scripts/run-integration-tests.sh --tool github-actions
./scripts/run-integration-tests.sh --tool gitlab-ci
./scripts/run-integration-tests.sh --tool codepipeline
```

### 2. パフォーマンス比較テス���

```bash
# ローカル実行時間の測定
time act -j test
time gitlab-runner exec docker test
time ./scripts/test-buildspec.sh cicd/buildspecs/test.yml

# 比較レポートの生成
python scripts/analyze-cicd-configs.py --local-mode
```

### 3. 設定ファイル検証

```bash
# 全設定ファイルの構文チェック
./scripts/validate-all-configs.sh

# GitHub Actionsワークフローの検証
act --list

# GitLab CI/CD設定の検証
python -c "import yaml; print('GitLab CI/CD YAML is valid')" < .gitlab-ci.yml

# buildspecファイルの検証
for file in cicd/buildspecs/*.yml; do
  echo "Validating $file..."
  python -c "import yaml; yaml.safe_load(open('$file'))"
done
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. act実行時のDocker関連エラー

**問題**: `Cannot connect to the Docker daemon`

**解決方法**:

```bash
# Dockerデーモンの起動確認
docker info

# Dockerデスクトップの再起動
# macOS: Docker Desktop を再起動
# Linux: sudo systemctl restart docker

# actの再実行
act --version
```

#### 2. GitLab Runner設定エラー

**問題**: `ERROR: Preparation failed: executor not supported`

**解決方法**:

```bash
# GitLab Runnerの設定確認
gitlab-runner verify

# 設定ファイルの修正
vim .gitlab-runner/config.toml

# Dockerイメージの確認
docker pull python:3.13
```

#### 3. LocalStack接続エラー

**問題**: `Could not connect to the endpoint URL`

**解決方法**:

```bash
# LocalStackの状態確認
localstack status

# LocalStackの再起動
localstack stop
localstack start

# エンドポイントURLの確認
echo $AWS_ENDPOINT_URL
```

#### 4. 環境変数関連エラー

**問題**: `Environment variable not set`

**解決方法**:

```bash
# 環境変数の確認
env | grep AWS
env | grep GITHUB

# .env.local ファイルの確認
cat .env.local

# 環境変数の再設定
source .env.local
```

### デバッグ用コマンド

```bash
# act詳細ログ
act -v --dryrun

# GitLab Runner詳細ログ
gitlab-runner --debug exec docker test

# Docker コンテナの確認
docker ps -a
docker logs <container-id>

# LocalStack ログ
localstack logs

# ファイル権限の確認
ls -la .actrc .gitlab-runner/config.toml .env.local
```

### パフォーマンス最適化

```bash
# Dockerイメージのキャッシュ
docker system prune -f
docker pull catthehacker/ubuntu:act-latest
docker pull python:3.13

# act実行の高速化
act --reuse

# GitLab Runner キャッシュの活用
gitlab-runner exec docker --cache-dir /tmp/cache test

# 並列実行
act -j test &
gitlab-runner exec docker test &
wait
```

### ローカルテスト用スクリプト

プロジェクトには以下のローカルテスト用スクリプトが含まれています：

```bash
# 全ローカルテストの実行
./scripts/run-all-local-tests.sh

# 特定ツールのテスト
./scripts/test-github-actions-local.sh
./scripts/test-gitlab-ci-local.sh  
./scripts/test-codepipeline-local.sh

# 設定ファイル検証
./scripts/validate-all-configs.sh

# パフォーマンス測定
./scripts/measure-local-performance.sh
```

---

このガイドに従ってローカルテスト環境を構築することで、クラウド環境にデプロイする前に各CI/CDツールの動作を確認し、問題を早期に発見できます。

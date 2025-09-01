# GitLab CI/CD ローカルテスト環境

GitLab CI/CDパイプラインをローカル環境でテストするためのガイドです。

## 概要

GitLab Runnerを使用してGitLab CI/CDパイプラインをローカルで実行し、GitLab.comにプッシュする前に動作を確認できます。

## 前提条件

### 必要なツール

1. **Docker**: コンテナ実行環境
2. **GitLab Runner**: GitLab CI/CDローカル実行ツール（オプション）
3. **Docker Compose**: マルチコンテナ管理（推奨）
4. **Git**: バージョン管理

### インストール方法

#### macOS (Homebrew)

```bash
# GitLab Runnerのインストール
brew install gitlab-runner

# Docker Composeのインストール（Docker Desktopに含まれる）
brew install --cask docker

# 追加ツール（オプション）
brew install yq  # YAML解析用
```

#### Linux

```bash
# GitLab Runnerのインストール（Ubuntu/Debian）
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Dockerのインストール
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker

# ユーザーをdockerグループに追加
sudo usermod -aG docker $USER
```

#### Windows

```powershell
# Chocolateyを使用
choco install gitlab-runner
choco install docker-desktop

# または、手動インストール
# GitLab Runner: https://docs.gitlab.com/runner/install/windows.html
```

## 設定ファイル

### .gitlab-runner/config.toml

GitLab Runnerの基本設定を行います。

```toml
concurrent = 4
check_interval = 0

[[runners]]
  name = "local-docker-runner"
  executor = "docker"
  
  [runners.docker]
    image = "ubuntu:22.04"
    privileged = false
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock",
      "/cache"
    ]
```

### .gitlab-runner/docker-compose.yml

Docker Composeを使用したGitLab Runner環境の設定です。

```yaml
version: '3.8'
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    volumes:
      - ./config.toml:/etc/gitlab-runner/config.toml:ro
      - /var/run/docker.sock:/var/run/docker.sock
```

### .gitlab-runner/.env

ローカル実行用の環境変数を設定します。

```bash
# GitLab CI/CD環境変数
CI=true
GITLAB_CI=true
CI_PIPELINE_SOURCE=push

# AWS設定
AWS_DEFAULT_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012

# ローカルテスト用フラグ
LOCAL_TEST=true
SKIP_AWS_DEPLOY=true
```

## 使用方法

### 1. Docker Composeを使用した実行（推奨）

```bash
# GitLab Runnerサービスの起動
cd .gitlab-runner
docker-compose up -d

# 特定のジョブの実行
docker-compose exec gitlab-runner gitlab-runner exec docker lint

# 全ジョブの実行（手動で順次実行）
docker-compose exec gitlab-runner gitlab-runner exec docker test
docker-compose exec gitlab-runner gitlab-runner exec docker build

# サービスの停止
docker-compose down
```

### 2. 便利なスクリプトの使用

プロジェクトに含まれる`scripts/test-gitlab-ci.sh`スクリプトを使用すると、より簡単にテストできます。

```bash
# スクリプトに実行権限を付与
chmod +x scripts/test-gitlab-ci.sh

# 使用方法の確認
./scripts/test-gitlab-ci.sh --help

# Docker Composeを使用した実行
./scripts/test-gitlab-ci.sh --docker

# 特定のジョブの実行
./scripts/test-gitlab-ci.sh lint

# 特定のステージのジョブ実行
./scripts/test-gitlab-ci.sh --stage test

# 構文チェックのみ
./scripts/test-gitlab-ci.sh --validate

# 利用可能なジョブ一覧
./scripts/test-gitlab-ci.sh --list

# ドライラン
./scripts/test-gitlab-ci.sh --dry-run
```

### 3. ローカルGitLab Runnerを使用した実行

GitLab Runnerがローカルにインストールされている場合：

```bash
# 特定のジョブの実行
gitlab-runner exec docker lint

# 異なるExecutorの使用
gitlab-runner exec shell test

# Kubernetesでの実行（K8sクラスターが必要）
gitlab-runner exec kubernetes deploy
```

## 高度な使用方法

### 1. カスタムDockerイメージの使用

```bash
# .gitlab-ci.ymlで指定されたイメージを使用
gitlab-runner exec docker --docker-image python:3.13 test

# 特定のイメージでの実行
gitlab-runner exec docker --docker-image node:18 lint
```

### 2. 環境変数の設定

```bash
# 環境変数を指定して実行
gitlab-runner exec docker \
  --env AWS_DEFAULT_REGION=us-east-1 \
  --env STAGE_NAME=dev \
  test
```

### 3. ボリュームマウント

```bash
# 追加のボリュームをマウント
gitlab-runner exec docker \
  --docker-volumes /host/path:/container/path \
  build
```

### 4. 並列実行

```bash
# 複数のジョブを並列実行（手動）
gitlab-runner exec docker lint &
gitlab-runner exec docker test &
wait
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. GitLab Runnerが見つからない

```bash
# Docker Composeを使用
./scripts/test-gitlab-ci.sh --docker

# または、Dockerで直接実行
docker run --rm -v $PWD:$PWD -w $PWD gitlab/gitlab-runner:latest exec docker lint
```

#### 2. Docker権限エラー

```bash
# ユーザーをdockerグループに追加
sudo usermod -aG docker $USER

# 新しいシェルセッションを開始
newgrp docker
```

#### 3. .gitlab-ci.yml構文エラー

```bash
# 構文チェック
./scripts/test-gitlab-ci.sh --validate

# YAMLの基本構文チェック
python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"
```

#### 4. AWS認証エラー

ローカルテスト時はAWSデプロイをスキップ：

```bash
# .gitlab-runner/.envに追加
SKIP_AWS_DEPLOY=true
LOCAL_TEST=true
```

#### 5. メモリ不足エラー

```bash
# Docker Composeでメモリ制限を調整
# docker-compose.ymlに追加:
# mem_limit: 2g
# memswap_limit: 2g
```

### ログの確認

```bash
# GitLab Runnerのログ
docker-compose logs gitlab-runner

# 特定のジョブの詳細ログ
gitlab-runner exec docker --debug lint

# CI変数の確認
gitlab-runner exec docker --env CI_DEBUG_TRACE=true test
```

## 制限事項

### GitLab Runnerの制限

1. **GitLab固有の機能**: 一部のGitLab固有の機能は模擬実行
2. **CI/CD変数**: GitLab CI/CD変数は環境変数ファイルで代替
3. **外部サービス**: 実際のAWSサービスへの接続は制限される場合がある
4. **並列実行**: `parallel`キーワードは手動で複数回実行が必要
5. **依存関係**: `needs`キーワードは手動で順序を管理

### 推奨される使用方法

1. **構文チェック**: .gitlab-ci.ymlファイルの構文確認
2. **ロジックテスト**: 基本的なスクリプトロジックの確認
3. **環境変数テスト**: 環境変数の設定と参照の確認
4. **依存関係テスト**: パッケージインストールの確認

## ベストプラクティス

### 1. 段階的テスト

```bash
# 1. 構文チェック
./scripts/test-gitlab-ci.sh --validate

# 2. 特定のジョブテスト
./scripts/test-gitlab-ci.sh lint

# 3. ステージ別テスト
./scripts/test-gitlab-ci.sh --stage test

# 4. 全体テスト
./scripts/test-gitlab-ci.sh --docker
```

### 2. 環境分離

```bash
# 開発用設定
cp .gitlab-runner/.env .gitlab-runner/.env.dev

# 本番用設定
cp .gitlab-runner/.env .gitlab-runner/.env.prod
```

### 3. キャッシュ活用

```bash
# キャッシュディレクトリの作成
mkdir -p .gitlab-runner/cache

# キャッシュを使用した実行
gitlab-runner exec docker --docker-volumes .gitlab-runner/cache:/cache test
```

### 4. セキュリティ

```bash
# 機密情報の環境変数化
echo "AWS_ACCESS_KEY_ID=your-key" >> .gitlab-runner/.env.local
echo "AWS_SECRET_ACCESS_KEY=your-secret" >> .gitlab-runner/.env.local

# .env.localをgitignoreに追加
echo ".gitlab-runner/.env.local" >> .gitignore
```

## CI/CDパイプラインの最適化

### 1. ジョブの依存関係管理

```yaml
# .gitlab-ci.yml例
stages:
  - cache
  - check
  - deploy

cache-job:
  stage: cache
  script: echo "Creating cache"

lint:
  stage: check
  needs: ["cache-job"]
  script: echo "Running lint"

test:
  stage: check
  needs: ["cache-job"]
  script: echo "Running tests"
```

### 2. 条件付き実行

```yaml
deploy:
  stage: deploy
  script: echo "Deploying"
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $LOCAL_TEST != "true"
```

### 3. アーティファクトの管理

```bash
# アーティファクトディレクトリの作成
mkdir -p artifacts

# ローカルでのアーティファクト確認
ls -la artifacts/
```

## 参考資料

- [GitLab Runner公式ドキュメント](https://docs.gitlab.com/runner/)
- [GitLab CI/CD公式ドキュメント](https://docs.gitlab.com/ee/ci/)
- [Docker公式ドキュメント](https://docs.docker.com/)
- [GitLab CI/CD YAML構文リファレンス](https://docs.gitlab.com/ee/ci/yaml/)

## サポート

問題が発生した場合は、以下を確認してください：

1. GitLab Runnerのバージョン: `gitlab-runner --version`
2. Dockerの状態: `docker info`
3. .gitlab-ci.ymlの構文: `./scripts/test-gitlab-ci.sh --validate`
4. 環境変数の設定: `.gitlab-runner/.env`ファイルの内容
5. ログの確認: `docker-compose logs gitlab-runner`

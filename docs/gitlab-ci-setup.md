# GitLab CI/CD セットアップガイド

このドキュメントでは、GitLab CI/CDでCI/CDパイプラインを設定する手順を説明します。

## 📋 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [プロジェクト設定](#プロジェクト設定)
- [変数とシークレット管理](#変数とシークレット管理)
- [パイプライン設定](#パイプライン設定)
- [ローカルテスト](#ローカルテスト)
- [トラブルシューティング](#トラブルシューティング)

## 🎯 概要

GitLab CI/CDパイプラインは以下の特徴を持ちます：

- **統合開発環境**: GitLabの全機能との連携
- **柔軟なRunner**: 共有Runner、専用Runner、Kubernetes Runner
- **高度なキャッシュ**: 分散キャッシュとアーティファクト管理
- **セキュリティスキャン**: 組み込みのセキュリティ機能

## 📋 前提条件

### 必要なツール

- GitLab アカウント（GitLab.com または自社インスタンス）
- AWS アカウント
- AWS CLI v2
- Docker（ローカルテスト用）

### GitLabプロジェクト設定

1. **プロジェクトの作成**

   ```bash
   # GitLabでプロジェクトを作成後
   git clone https://gitlab.com/your-username/your-project.git
   cd your-project
   ```

2. **ブランチ保護の設定**
   - Settings > Repository > Push Rules
   - `main`ブランチの保護ルールを設定
   - "Allowed to push"と"Allowed to merge"を制限

## ⚙️ プロジェクト設定

### CI/CD設定の有効化

1. **Settings > General > Visibility, project features, permissions**
2. **CI/CD**を有効化
3. **Container Registry**を有効化（Dockerイメージ用）

### Runner設定

#### 共有Runnerの使用

1. **Settings > CI/CD > Runners**
2. **Enable shared runners for this project**を有効化

#### 専用Runnerの設定

```bash
# GitLab Runnerのインストール
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo yum install gitlab-runner

# Runnerの登録
sudo gitlab-runner register \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_REGISTRATION_TOKEN" \
  --description "My Runner" \
  --tag-list "docker,aws" \
  --executor "docker" \
  --docker-image "alpine:latest"
```

## 🔒 変数とシークレット管理

### プロジェクト変数の設定

Settings > CI/CD > Variables で以下を設定：

#### AWS認証情報

| 変数名 | 値 | 保護 | マスク | 説明 |
|--------|---|------|------|------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | ✅ | ✅ | AWSアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | `...` | ✅ | ✅ | AWSシークレットアクセスキー |
| `AWS_DEFAULT_REGION` | `ap-northeast-1` | ❌ | ❌ | AWSリージョン |
| `AWS_ACCOUNT_ID` | `123456789012` | ❌ | ❌ | AWSアカウントID |

#### アプリケーション設定

| 変数名 | 値 | 保護 | マスク | 説明 |
|--------|---|------|------|------|
| `ECR_REPOSITORY` | `cicd-comparison-api` | ❌ | ❌ | ECRリポジトリ名 |
| `ECS_CLUSTER` | `cicd-comparison-cluster` | ❌ | ❌ | ECSクラスター名 |
| `ECS_SERVICE` | `cicd-comparison-service` | ❌ | ❌ | ECSサービス名 |
| `CODEDEPLOY_APPLICATION` | `cicd-comparison-app` | ❌ | ❌ | CodeDeployアプリケーション名 |

### 環境別変数

#### Production環境

Settings > CI/CD > Variables で環境スコープを`production`に設定：

| 変数名 | 値 | 環境 |
|--------|---|------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | `production` |
| `ECS_CLUSTER` | `cicd-comparison-prod-cluster` | `production` |

#### Staging環境

環境スコープを`staging`に設定：

| 変数名 | 値 | 環境 |
|--------|---|------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | `staging` |
| `ECS_CLUSTER` | `cicd-comparison-stg-cluster` | `staging` |

## 🔄 パイプライン設定

### メインパイプライン

`.gitlab-ci.yml`を作成：

```yaml
# GitLab CI/CD設定
image: python:3.13

# ステージ定義
stages:
  - cache
  - check
  - deploy

# 変数定義
variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
  UV_CACHE_DIR: "$CI_PROJECT_DIR/.cache/uv"
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

# キャッシュ設定
cache:
  key: 
    files:
      - uv.lock
      - .tool-versions
  paths:
    - .cache/pip/
    - .cache/uv/
    - .venv/

# 共通スクリプト
.install_dependencies: &install_dependencies
  - curl -LsSf https://astral.sh/uv/install.sh | sh
  - export PATH="$HOME/.cargo/bin:$PATH"
  - uv sync --dev

.aws_setup: &aws_setup
  - pip install awscli
  - aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
  - aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
  - aws configure set default.region $AWS_DEFAULT_REGION

# キャッシュ作成ジョブ
create_cache:
  stage: cache
  script:
    - *install_dependencies
    - echo "Dependencies cached"
  artifacts:
    paths:
      - .venv/
    expire_in: 1 hour

# チェック工程（並列実行）
lint:
  stage: check
  needs: ["create_cache"]
  script:
    - *install_dependencies
    - uv run ruff check .
    - uv run black --check .
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

test:
  stage: check
  needs: ["create_cache"]
  script:
    - *install_dependencies
    - uv run pytest --cov=modules/api --cov-report=xml --cov-report=term
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
    paths:
      - htmlcov/
    expire_in: 1 week
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

# SCAチェック（GitLab Dependency Scanning + CodeGuru Security）
sca_gitlab:
  stage: check
  needs: ["create_cache"]
  image: registry.gitlab.com/security-products/dependency-scanning:latest
  script:
    - /analyzer run
  artifacts:
    reports:
      dependency_scanning: gl-dependency-scanning-report.json
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

sca_codeguru:
  stage: check
  needs: ["create_cache"]
  image: amazon/aws-cli:latest
  before_script:
    - *aws_setup
    - yum update -y && yum install -y zip jq curl
  script:
    - ./scripts/run-codeguru-security.sh "gitlab-sca-$CI_PIPELINE_ID" "." "$AWS_DEFAULT_REGION"
  artifacts:
    reports:
      sast: gitlab-sca-$CI_PIPELINE_ID.json
    expire_in: 1 week
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# SASTチェック（GitLab SAST + Amazon Inspector）
sast_gitlab:
  stage: check
  needs: ["create_cache"]
  image: registry.gitlab.com/security-products/sast:latest
  script:
    - /analyzer run
  artifacts:
    reports:
      sast: gl-sast-report.json
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

sast_inspector:
  stage: check
  needs: ["create_cache"]
  image: amazon/aws-cli:latest
  before_script:
    - *aws_setup
    - yum update -y && yum install -y zip jq
  script:
    - zip -r source-code.zip . -x "*.git*" ".cache/*" ".venv/*"
    - ./scripts/run-inspector-scan.sh "gitlab-sast-$CI_PIPELINE_ID" "source-code.zip" "$AWS_DEFAULT_REGION"
  artifacts:
    reports:
      sast: gitlab-sast-$CI_PIPELINE_ID.json
    expire_in: 1 week
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# デプロイ工程（並列実行）
deploy_lambda:
  stage: deploy
  image: amazon/aws-cli:latest
  needs: ["lint", "test", "sca_gitlab", "sast_gitlab"]
  environment:
    name: production/lambda
    url: https://$LAMBDA_API_ID.execute-api.$AWS_DEFAULT_REGION.amazonaws.com/prod
  before_script:
    - *aws_setup
    - yum update -y && yum install -y python3 python3-pip
    - pip3 install aws-sam-cli
  script:
    - sam build
    - sam deploy --no-confirm-changeset --no-fail-on-empty-changeset --stack-name cicd-comparison-lambda
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy_ecs:
  stage: deploy
  image: docker:latest
  services:
    - docker:dind
  needs: ["lint", "test", "sca_gitlab", "sast_gitlab"]
  environment:
    name: production/ecs
    url: https://$ECS_ALB_DNS
  before_script:
    - apk add --no-cache python3 py3-pip
    - pip3 install awscli
    - *aws_setup
    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
  script:
    - docker build -t $ECR_REPOSITORY .
    - docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPOSITORY:$CI_COMMIT_SHA
    - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPOSITORY:$CI_COMMIT_SHA
    - ./scripts/deploy-ecs-blue-green.sh $CI_COMMIT_SHA
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy_ec2:
  stage: deploy
  image: amazon/aws-cli:latest
  needs: ["lint", "test", "sca_gitlab", "sast_gitlab"]
  environment:
    name: production/ec2
    url: https://$EC2_ALB_DNS
  before_script:
    - *aws_setup
    - yum update -y && yum install -y zip
  script:
    - zip -r deployment.zip . -x "*.git*" ".cache/*" ".venv/*" "*.zip"
    - aws s3 cp deployment.zip s3://$DEPLOYMENT_BUCKET/deployments/$CI_COMMIT_SHA.zip
    - ./scripts/deploy_ec2-codedeploy.sh $CI_COMMIT_SHA
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# ステージング環境デプロイ
deploy_staging:
  stage: deploy
  extends: .deploy_template
  environment:
    name: staging
  variables:
    STAGE: staging
  script:
    - export STAGE=staging
    - ./scripts/deploy-all.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

# マニュアルデプロイ
deploy_manual:
  stage: deploy
  extends: deploy_lambda
  when: manual
  environment:
    name: manual
  rules:
    - if: $CI_PIPELINE_SOURCE == "web"
```

### 環境別設定

#### ステージング環境用パイプライン

`.gitlab-ci-staging.yml`を作成し、メインパイプラインでinclude：

```yaml
# ステージング環境専用設定
include:
  - local: '.gitlab-ci-staging.yml'

# ステージング環境のジョブ
staging_deploy:
  extends: .deploy_template
  environment:
    name: staging
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID_STAGING
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY_STAGING
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
```

### セキュリティスキャン設定

#### Dependency Scanning

`.gitlab-ci.yml`に追加：

```yaml
include:
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml

# カスタムDependency Scanning
dependency_scanning:
  variables:
    DS_PYTHON_VERSION: "3.13"
    DS_PIP_DEPENDENCY_PATH: "requirements.txt"
```

#### SAST設定

```yaml
sast:
  variables:
    SAST_PYTHON_VERSION: "3.13"
    SAST_EXCLUDED_PATHS: "tests/, .venv/, .cache/"
```

## 🧪 ローカルテスト

### GitLab Runnerのローカルインストール

#### macOS

```bash
# Homebrewでインストール
brew install gitlab-runner

# 手動インストール
sudo curl --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-amd64"
sudo chmod +x /usr/local/bin/gitlab-runner
```

#### Linux

```bash
# Debian/Ubuntu
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# CentOS/RHEL
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo yum install gitlab-runner
```

### ローカル実行設定

#### 設定ファイル

`.gitlab-runner/config.toml`を作成：

```toml
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "local-docker-runner"
  url = "https://gitlab.com/"
  token = "your-runner-token"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "python:3.13"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
```

### ローカル実行

```bash
# 特定のジョブの実行
gitlab-runner exec docker test

# 環境変数を指定して実行
gitlab-runner exec docker --env AWS_DEFAULT_REGION=ap-northeast-1 test

# 設定ファイルを指定して実行
gitlab-runner --config .gitlab-runner/config.toml exec docker test

# デバッグモード
gitlab-runner --debug exec docker test
```

### Docker Composeでの実行

`docker-compose.yml`を作成：

```yaml
version: '3.8'

services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    volumes:
      - .gitlab-runner:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock
    command: ["gitlab-runner", "exec", "docker", "test"]
```

実行：

```bash
docker-compose run gitlab-runner
```

## 🔧 トラブルシューティング

### よくある問題

#### 1. Runner接続エラー

**エラー**: `ERROR: Registering runner... failed`

**解決策**:

```bash
# Runnerトークンの確認
# Settings > CI/CD > Runners > Registration token

# ネットワーク接続の確認
curl -I https://gitlab.com/

# Runnerの再登録
sudo gitlab-runner unregister --all-runners
sudo gitlab-runner register
```

#### 2. Docker権限エラー

**エラー**: `permission denied while trying to connect to the Docker daemon socket`

**解決策**:

```bash
# ユーザーをdockerグループに追加
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner

# または特権モードを有効化
# config.tomlでprivileged = true
```

#### 3. キャッシュの問題

**エラー**: `Cache not found`

**解決策**:

```yaml
# キャッシュポリシーの調整
cache:
  key: "$CI_COMMIT_REF_SLUG"
  policy: pull-push
  paths:
    - .cache/
```

#### 4. 環境変数が認識されない

**解決策**:

```bash
# 変数の確認
echo $AWS_ACCESS_KEY_ID

# GitLab UIで変数の設定を確認
# Settings > CI/CD > Variables

# 変数のスコープを確認（環境、ブランチ）
```

### デバッグ方法

#### 1. ジョブログの詳細化

```yaml
variables:
  CI_DEBUG_TRACE: "true"  # 詳細ログを有効化

script:
  - set -x  # シェルのデバッグモード
  - echo "Debug info: $CI_JOB_NAME"
```

#### 2. アーティファクトでのデバッグ

```yaml
artifacts:
  when: always
  paths:
    - logs/
    - debug/
  expire_in: 1 day
```

#### 3. 失敗時の調査

```yaml
after_script:
  - echo "Job status: $CI_JOB_STATUS"
  - if [ "$CI_JOB_STATUS" == "failed" ]; then
      echo "Collecting debug information...";
      env > debug_env.txt;
    fi
```

### パフォーマンス最適化

#### 1. 並列実行の最適化

```yaml
test:
  parallel:
    matrix:
      - PYTHON_VERSION: ["3.11", "3.12", "3.13"]
```

#### 2. キャッシュの最適化

```yaml
cache:
  key:
    files:
      - uv.lock
      - requirements.txt
  paths:
    - .cache/pip/
    - .cache/uv/
    - .venv/
  policy: pull-push
```

#### 3. 条件付き実行

```yaml
rules:
  - if: $CI_COMMIT_MESSAGE =~ /\[skip ci\]/
    when: never
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"
  - if: $CI_COMMIT_BRANCH == "main"
```

## 📊 監視とレポート

### パイプライン監視

1. **CI/CD > Pipelines**でパイプライン状況を確認
2. **CI/CD > Jobs**で個別ジョブの詳細を確認
3. **Monitor > CI/CD Analytics**でパフォーマンス分析

### セキュリティレポート

1. **Security & Compliance > Security Dashboard**
2. **Security & Compliance > Vulnerability Report**
3. **Security & Compliance > Dependency List**

### カバレッジレポート

```yaml
test:
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

## 📚 参考資料

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab Security Scanning](https://docs.gitlab.com/ee/user/application_security/)
- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)

# GitHub Actions セットアップガイド

このドキュメントでは、GitHub ActionsでCI/CDパイプラインを設定する手順を説明します。

## 📋 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [AWS認証設定](#aws認証設定)
- [ワークフロー設定](#ワークフロー設定)
- [シークレット管理](#シークレット管理)
- [ローカルテスト](#ローカルテスト)
- [トラブルシューティング](#トラブルシューティング)

## 🎯 概要

GitHub Actionsパイプラインは以下の特徴を持ちます：

- **並列実行**: チェック工程を並列で実行し、高速化を実現
- **OIDC認証**: セキュアなAWS認証（推奨）
- **マトリックス戦略**: 複数環境での同時テスト
- **キャッシュ機能**: 依存関係のキャッシュで実行時間短縮

## 📋 前提条件

### 必要なツール

- GitHub アカウント
- AWS アカウント
- AWS CLI v2
- 適切なIAM権限

### リポジトリ設定

1. **リポジトリの作成**

   ```bash
   # GitHubでリポジトリを作成後
   git clone https://github.com/your-username/your-repo.git
   cd your-repo
   ```

2. **ブランチ保護の設定**
   - Settings > Branches
   - `main`ブランチの保護ルールを追加
   - "Require status checks to pass before merging"を有効化

## 🔐 AWS認証設定

### Option 1: OIDC認証（推奨）

#### 1. IAMロールの作成

```bash
# CDKでOIDCプロバイダーとロールを作成
cd cdk
npx cdk deploy --context enableGitHubOIDC=true
```

または手動で作成：

```json
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:your-username/your-repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

#### 2. GitHub Secretsの設定

Repository Settings > Secrets and variables > Actions で以下を設定：

| Secret名 | 値 | 説明 |
|----------|---|------|
| `AWS_ROLE_ARN` | `arn:aws:iam::ACCOUNT-ID:role/GitHubActionsRole` | AssumeするIAMロール |
| `AWS_REGION` | `ap-northeast-1` | AWSリージョン |

### Option 2: アクセスキー認証

#### GitHub Secretsの設定

| Secret名 | 値 | 説明 |
|----------|---|------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | AWSアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | `...` | AWSシークレットアクセスキー |
| `AWS_REGION` | `ap-northeast-1` | AWSリージョン |

## ⚙️ ワークフロー設定

### メインワークフロー

`.github/workflows/ci.yml`を作成：

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  PYTHON_VERSION: '3.13'
  NODE_VERSION: '18'

jobs:
  # チェック工程（並列実行）
  lint:
    name: 静的解析
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Python環境のセットアップ
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: uvのインストール
        run: curl -LsSf https://astral.sh/uv/install.sh | sh
      
      - name: 依存関係のインストール
        run: uv sync --dev
      
      - name: ruffによるlint
        run: uv run ruff check .
      
      - name: blackによるフォーマットチェック
        run: uv run black --check .

  test:
    name: ユニットテスト
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Python環境のセットアップ
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: uvのインストール
        run: curl -LsSf https://astral.sh/uv/install.sh | sh
      
      - name: 依存関係のインストール
        run: uv sync --dev
      
      - name: pytestの実行
        run: uv run pytest --cov=modules/api --cov-report=xml
      
      - name: カバレッジレポートのアップロード
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml

  sca:
    name: SCAチェック
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: AWS認証（OIDC）
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Dependabotアラートの確認
        run: |
          # GitHub APIを使用してDependabotアラートを確認
          curl -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
               -H "Accept: application/vnd.github.v3+json" \
               https://api.github.com/repos/${{ github.repository }}/dependabot/alerts
      
      - name: CodeGuru Securityスキャン
        run: |
          # CodeGuru Securityでスキャンを実行
          ./scripts/run-codeguru-security.sh

  sast:
    name: SASTチェック
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4
      
      - name: CodeQLの初期化
        uses: github/codeql-action/init@v2
        with:
          languages: python
      
      - name: CodeQL解析の実行
        uses: github/codeql-action/analyze@v2
      
      - name: AWS認証（OIDC）
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Amazon Inspectorスキャン
        run: |
          # Amazon Inspectorでスキャンを実行
          ./scripts/run-inspector-scan.sh

  # デプロイ工程（チェック工程完了後に並列実行）
  deploy-lambda:
    name: Lambda デプロイ
    needs: [lint, test, sca, sast]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: AWS認証（OIDC）
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: SAM CLIのセットアップ
        uses: aws-actions/setup-sam@v2
      
      - name: SAMビルド
        run: sam build
      
      - name: SAMデプロイ
        run: sam deploy --no-confirm-changeset --no-fail-on-empty-changeset

  deploy-ecs:
    name: ECS デプロイ
    needs: [lint, test, sca, sast]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: AWS認証（OIDC）
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: ECRログイン
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Dockerイメージのビルドとプッシュ
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: cicd-comparison-api
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
      
      - name: ECS Blue/Greenデプロイ
        run: |
          # ECSタスク定義の更新とサービスデプロイ
          ./scripts/deploy-ecs-blue-green.sh

  deploy-ec2:
    name: EC2 デプロイ
    needs: [lint, test, sca, sast]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: AWS認証（OIDC）
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: CodeDeploy Blue/Greenデプロイ
        run: |
          # CodeDeployでのデプロイメント実行
          ./scripts/deploy-ec2-codedeploy.sh
```

### 環境別ワークフロー

`.github/workflows/deploy-staging.yml`（ステージング環境用）：

```yaml
name: Deploy to Staging

on:
  push:
    branches: [ develop ]

jobs:
  deploy-staging:
    name: ステージング環境デプロイ
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      
      - name: AWS認証
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_STAGING }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: デプロイ実行
        run: |
          # ステージング環境へのデプロイ
          export STAGE=staging
          ./scripts/deploy-all.sh
```

## 🔒 シークレット管理

### Repository Secrets

Settings > Secrets and variables > Actions で設定：

#### AWS関連

| Secret名 | 説明 | 例 |
|----------|------|---|
| `AWS_ROLE_ARN` | AssumeするIAMロール | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
| `AWS_REGION` | AWSリージョン | `ap-northeast-1` |
| `AWS_ACCOUNT_ID` | AWSアカウントID | `123456789012` |

#### アプリケーション関連

| Secret名 | 説明 | 例 |
|----------|------|---|
| `ECR_REPOSITORY` | ECRリポジトリ名 | `cicd-comparison-api` |
| `ECS_CLUSTER` | ECSクラスター名 | `cicd-comparison-cluster` |
| `ECS_SERVICE` | ECSサービス名 | `cicd-comparison-service` |

### Environment Secrets

本番環境とステージング環境で異なる値を使用する場合：

1. Settings > Environments
2. 環境名を作成（例：`production`, `staging`）
3. 環境固有のシークレットを設定

## 🧪 ローカルテスト

### actツールのセットアップ

```bash
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Windows (Chocolatey)
choco install act-cli
```

### 設定ファイル

`.actrc`を作成：

```
--container-architecture linux/amd64
--artifact-server-path /tmp/artifacts
--env-file .env.local
--secret-file .secrets
--platform ubuntu-latest=catthehacker/ubuntu:act-latest
```

### ローカル実行

```bash
# 全ワークフローの実行
act

# 特定のジョブの実行
act -j test

# プルリクエストイベントのシミュレート
act pull_request

# 環境変数の指定
act -s AWS_REGION=ap-northeast-1

# デバッグモード
act -v
```

### 制限事項

- AWS認証は模擬実行
- 一部のGitHub固有機能は利用不可
- 実際のデプロイは実行されない

## 🔧 トラブルシューティング

### よくある問題

#### 1. OIDC認証エラー

**エラー**: `Error: Could not assume role with OIDC`

**解決策**:

```bash
# IAMロールの信頼関係を確認
aws iam get-role --role-name GitHubActionsRole

# OIDCプロバイダーの確認
aws iam list-open-id-connect-providers
```

#### 2. 権限エラー

**エラー**: `AccessDenied: User is not authorized to perform`

**解決策**:

```bash
# IAMポリシーの確認
aws iam list-attached-role-policies --role-name GitHubActionsRole

# 必要な権限の追加
aws iam attach-role-policy --role-name GitHubActionsRole --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

#### 3. タイムアウトエラー

**エラー**: `The job running on runner has exceeded the maximum execution time`

**解決策**:

```yaml
jobs:
  test:
    timeout-minutes: 30  # デフォルトは360分
```

#### 4. キャッシュの問題

**解決策**:

```bash
# キャッシュのクリア（GitHub UI）
# Settings > Actions > Caches

# または新しいキャッシュキーを使用
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    key: ${{ runner.os }}-uv-${{ hashFiles('uv.lock') }}-v2
```

### デバッグ方法

#### 1. ログの詳細化

```yaml
- name: デバッグ情報の出力
  run: |
    echo "GitHub Context:"
    echo "${{ toJson(github) }}"
    echo "Environment Variables:"
    env | sort
```

#### 2. SSH接続でのデバッグ

```yaml
- name: SSH接続の設定
  uses: mxschmitt/action-tmate@v3
  if: failure()
```

#### 3. アーティファクトの保存

```yaml
- name: ログの保存
  uses: actions/upload-artifact@v3
  if: always()
  with:
    name: logs
    path: |
      logs/
      *.log
```

### パフォーマンス最適化

#### 1. 並列実行の最適化

```yaml
strategy:
  matrix:
    python-version: [3.11, 3.12, 3.13]
  max-parallel: 3
```

#### 2. キャッシュの活用

```yaml
- name: 依存関係のキャッシュ
  uses: actions/cache@v3
  with:
    path: |
      ~/.cache/uv
      ~/.cache/pip
    key: ${{ runner.os }}-python-${{ hashFiles('uv.lock') }}
```

#### 3. 条件付き実行

```yaml
- name: テストの実行
  if: contains(github.event.head_commit.message, '[test]') || github.event_name == 'pull_request'
  run: uv run pytest
```

## 📚 参考資料

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [AWS Actions for GitHub](https://github.com/aws-actions)
- [act - Run GitHub Actions locally](https://github.com/nektos/act)
- [OIDC with AWS](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

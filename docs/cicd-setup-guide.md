# CI/CDツール設定ガイド

このドキュメントでは、GitHub Actions、GitLab CI/CD、AWS CodePipelineの3つのCI/CDツールの設定手順と、各ツール専用のAWSリソースへのアクセス方法について説明します。

## 📋 目次

- [前提条件](#前提条件)
- [GitHub Actions設定](#github-actions設定)
- [GitLab CI/CD設定](#gitlab-cicd設定)
- [AWS CodePipeline設定](#aws-codepipeline設定)
- [専用リソースへのアクセス](#専用リソースへのアクセス)
- [トラブルシューティング](#トラブルシューティング)

## 🔧 前提条件

### 必要なツール

| ツール | バージョン | インストール方法 |
|--------|-----------|-----------------|
| AWS CLI | v2+ | `brew install awscli` |
| Node.js | 18+ | `asdf install nodejs 18.17.0` |
| Python | 3.13 | `asdf install python 3.13.0` |
| uv | latest | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Docker | latest | Docker Desktop |

### AWS設定

```bash
# AWS認証情報の設定
aws configure
# または
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1

# 認証確認
aws sts get-caller-identity
```

### インフラストラクチャのデプロイ

```bash
# CDKのブートストラップ（初回のみ）
cd cdk
npx cdk bootstrap

# 全インフラのデプロイ
npx cdk deploy --all --require-approval never

# デプロイ確認
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
```

## 🐙 GitHub Actions設定

### 1. リポジトリ設定

#### GitHub Secretsの設定

GitHub リポジトリの Settings > Secrets and variables > Actions で以下を設定：

| Secret名 | 値 | 説明 |
|----------|---|------|
| `AWS_ACCOUNT_ID` | `123456789012` | AWSアカウントID |
| `AWS_REGION` | `us-east-1` | AWSリージョン |

#### OIDC設定（推奨）

```bash
# GitHub OIDC Provider用のIAMロールを作成（オプション）
cd cdk
npx cdk deploy GitHubOIDCStack
```

OIDC使用時のワークフロー設定：

```yaml
# .github/workflows/ci.yml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: ${{ secrets.AWS_REGION }}
```

### 2. ワークフロー実行

#### 手動実行

1. GitHub リポジトリの Actions タブを開く
2. "CI/CD Pipeline" ワークフローを選択
3. "Run workflow" ボタンをクリック
4. ブランチを選択して実行

#### 自動実行

```bash
# mainブランチへのプッシュで自動実行
git add .
git commit -m "feat: trigger GitHub Actions pipeline"
git push origin main
```

### 3. GitHub Actions専用リソース

デプロイ後に作成されるリソース：

| リソース種類 | リソース名 | 用途 |
|-------------|-----------|------|
| Lambda関数 | `github-local-lambda-api` | サーバーレスAPI |
| API Gateway | `github-local-api-gateway` | Lambda統合 |
| ECSクラスター | `github-local-ecs-cluster` | コンテナ実行 |
| ALB | `github-local-ecs-alb` | ECS負荷分散（Port 8080） |
| EC2インスタンス | `github-local-ec2-instance` | 従来型デプロイ |
| ALB | `github-local-ec2-alb` | EC2負荷分散（Port 8080） |
| CodeDeployアプリ | `github-local-codedeploy-app` | Blue/Greenデプロイ |

## 🦊 GitLab CI/CD設定

### 1. プロジェクト設定

#### GitLab CI/CD変数の設定

GitLab プロジェクトの Settings > CI/CD > Variables で以下を設定：

| 変数名 | 値 | 保護 | マスク |
|--------|---|------|-------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | ✓ | ✓ |
| `AWS_SECRET_ACCESS_KEY` | `secret-key` | ✓ | ✓ |
| `AWS_DEFAULT_REGION` | `us-east-1` | - | - |
| `AWS_ACCOUNT_ID` | `123456789012` | - | - |

#### GitLab Runner設定

```bash
# GitLab Runnerの登録（セルフホスト環境の場合）
gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token $REGISTRATION_TOKEN \
  --executor docker \
  --docker-image python:3.13 \
  --description "CI/CD Comparison Runner"
```

### 2. パイプライン実行

#### 手動実行

1. GitLab プロジェクトの CI/CD > Pipelines を開く
2. "Run pipeline" ボタンをクリック
3. ブランチを選択して実行

#### 自動実行

```bash
# mainブランチへのプッシュで自動実行
git add .
git commit -m "feat: trigger GitLab CI/CD pipeline"
git push origin main
```

### 3. GitLab CI/CD専用リソース

デプロイ後に作成されるリソース：

| リソース種類 | リソース名 | 用途 |
|-------------|-----------|------|
| Lambda関数 | `gitlab-local-lambda-api` | サーバーレスAPI |
| API Gateway | `gitlab-local-api-gateway` | Lambda統合 |
| ECSクラスター | `gitlab-local-ecs-cluster` | コンテナ実行 |
| ALB | `gitlab-local-ecs-alb` | ECS負荷分散（Port 8081） |
| EC2インスタンス | `gitlab-local-ec2-instance` | 従来型デプロイ |
| ALB | `gitlab-local-ec2-alb` | EC2負荷分散（Port 8081） |
| CodeDeployアプリ | `gitlab-local-codedeploy-app` | Blue/Greenデプロイ |

## ☁️ AWS CodePipeline設定

### 1. パイプライン設定

CodePipelineは CDK デプロイ時に自動作成されます：

```bash
# CodePipelineスタックのデプロイ
cd cdk
npx cdk deploy PipelineStack
```

### 2. ソース設定

#### GitHub連携

```typescript
// cdk/lib/pipeline-stack.ts
const sourceOutput = new codepipeline.Artifact();
const sourceAction = new codepipeline_actions.GitHubSourceAction({
  actionName: 'GitHub_Source',
  owner: 'your-github-username',
  repo: 'your-repo-name',
  oauthToken: cdk.SecretValue.secretsManager('github-token'),
  output: sourceOutput,
  branch: 'main',
});
```

#### GitHub Personal Access Token設定

1. GitHub Settings > Developer settings > Personal access tokens
2. "Generate new token" で以下のスコープを選択：
   - `repo` (Full control of private repositories)
   - `admin:repo_hook` (Full control of repository hooks)
3. AWS Secrets Manager にトークンを保存：

```bash
aws secretsmanager create-secret \
  --name github-token \
  --description "GitHub Personal Access Token for CodePipeline" \
  --secret-string "ghp_your_token_here"
```

### 3. パイプライン実行

#### 手動実行

```bash
# AWS CLIでパイプライン実行
aws codepipeline start-pipeline-execution \
  --name codepipeline-local-pipeline

# AWSコンソールでの実行
# 1. CodePipeline コンソールを開く
# 2. "codepipeline-local-pipeline" を選択
# 3. "Release change" ボタンをクリック
```

#### 自動実行

GitHubリポジトリへのプッシュで自動実行されます：

```bash
git add .
git commit -m "feat: trigger CodePipeline"
git push origin main
```

### 4. CodePipeline専用リソース

デプロイ後に作成されるリソース：

| リソース種類 | リソース名 | 用途 |
|-------------|-----------|------|
| Pipeline | `codepipeline-local-pipeline` | メインパイプライン |
| CodeBuildプロジェクト | `codepipeline-local-*-build` | 各ビルドステージ |
| Lambda関数 | `codepipeline-local-lambda-api` | サーバーレスAPI |
| API Gateway | `codepipeline-local-api-gateway` | Lambda統合 |
| ECSクラスター | `codepipeline-local-ecs-cluster` | コンテナ実行 |
| ALB | `codepipeline-local-ecs-alb` | ECS負荷分散（Port 8082） |
| EC2インスタンス | `codepipeline-local-ec2-instance` | 従来型デプロイ |
| ALB | `codepipeline-local-ec2-alb` | EC2負荷分散（Port 8082） |
| CodeDeployアプリ | `codepipeline-local-codedeploy-app` | Blue/Greenデプロイ |

## 🌐 専用リソースへのアクセス

### エンドポイント一覧

各CI/CDツール専用のエンドポイントにアクセスして動作確認：

#### Lambda エンドポイント

```bash
# GitHub Actions専用
curl https://github-local-api-gateway.execute-api.us-east-1.amazonaws.com/prod/health

# GitLab CI/CD専用  
curl https://gitlab-local-api-gateway.execute-api.us-east-1.amazonaws.com/prod/health

# CodePipeline専用
curl https://codepipeline-local-api-gateway.execute-api.us-east-1.amazonaws.com/prod/health
```

#### ECS エンドポイント（ALB経由）

```bash
# GitHub Actions専用（Port 8080）
curl http://github-local-ecs-alb-123456789.us-east-1.elb.amazonaws.com:8080/health

# GitLab CI/CD専用（Port 8081）
curl http://gitlab-local-ecs-alb-123456789.us-east-1.elb.amazonaws.com:8081/health

# CodePipeline専用（Port 8082）
curl http://codepipeline-local-ecs-alb-123456789.us-east-1.elb.amazonaws.com:8082/health
```

#### EC2 エンドポイント（ALB経由）

```bash
# GitHub Actions専用（Port 8080）
curl http://github-local-ec2-alb-123456789.us-east-1.elb.amazonaws.com:8080/health

# GitLab CI/CD専用（Port 8081）
curl http://gitlab-local-ec2-alb-123456789.us-east-1.elb.amazonaws.com:8081/health

# CodePipeline専用（Port 8082）
curl http://codepipeline-local-ec2-alb-123456789.us-east-1.elb.amazonaws.com:8082/health
```

### エンドポイント取得方法

```bash
# CDK出力からエンドポイントを取得
cd cdk
npx cdk deploy --outputs-file outputs.json
cat outputs.json | jq '.[] | select(.OutputKey | contains("Endpoint"))'

# AWS CLIでALBのDNS名を取得
aws elbv2 describe-load-balancers \
  --names github-local-ecs-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# API GatewayのエンドポイントURL取得
aws apigateway get-rest-apis \
  --query 'items[?name==`github-local-api-gateway`].id' \
  --output text
```

### CloudWatchログの確認

各CI/CDツール専用のロググループ：

```bash
# Lambda関数ログ
aws logs tail /aws/lambda/github-local-lambda-api --follow
aws logs tail /aws/lambda/gitlab-local-lambda-api --follow  
aws logs tail /aws/lambda/codepipeline-local-lambda-api --follow

# ECSタスクログ
aws logs tail /ecs/github-local-ecs-api --follow
aws logs tail /ecs/gitlab-local-ecs-api --follow
aws logs tail /ecs/codepipeline-local-ecs-api --follow

# EC2アプリケーションログ
aws logs tail /aws/ec2/github-local-ec2-api --follow
aws logs tail /aws/ec2/gitlab-local-ec2-api --follow
aws logs tail /aws/ec2/codepipeline-local-ec2-api --follow
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. GitHub Actions認証エラー

**問題**: `Error: Could not assume role with OIDC`

**解決方法**:

```bash
# OIDC設定の確認
aws iam get-role --role-name github-actions-role

# トラストポリシーの確認
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument'

# GitHub Secretsの再設定
# AWS_ACCOUNT_ID と AWS_REGION が正しく設定されているか確認
```

#### 2. GitLab CI/CD変数エラー

**問題**: `AWS credentials not found`

**解決方法**:

```bash
# GitLab CI/CD変数の確認
# Settings > CI/CD > Variables で以下を確認：
# - AWS_ACCESS_KEY_ID (Protected, Masked)
# - AWS_SECRET_ACCESS_KEY (Protected, Masked)  
# - AWS_DEFAULT_REGION

# 変数のスコープ確認（プロジェクトレベルで設定）
```

#### 3. CodePipeline GitHub連携エラー

**問題**: `Source action failed: Invalid GitHub token`

**解決方法**:

```bash
# GitHub Personal Access Tokenの確認
aws secretsmanager get-secret-value --secret-id github-token

# トークンの権限確認（repo, admin:repo_hook が必要）
# 新しいトークンを生成して更新：
aws secretsmanager update-secret \
  --secret-id github-token \
  --secret-string "ghp_new_token_here"
```

#### 4. エンドポイントアクセスエラー

**問題**: `Connection timeout` または `404 Not Found`

**解決方法**:

```bash
# ALBの状態確認
aws elbv2 describe-load-balancers --names github-local-ecs-alb
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# セキュリティグループの確認
aws ec2 describe-security-groups --group-names github-local-ecs-sg

# ECS/EC2サービスの状態確認
aws ecs describe-services --cluster github-local-ecs-cluster --services github-local-ecs-service
aws ec2 describe-instances --filters "Name=tag:Name,Values=github-local-ec2-instance"
```

#### 5. デプロイ失敗

**問題**: Blue/Greenデプロイが失敗する

**解決方法**:

```bash
# CodeDeployデプロイメント状態確認
aws deploy list-deployments --application-name github-local-codedeploy-app
aws deploy get-deployment --deployment-id d-XXXXXXXXX

# ECSサービスイベント確認
aws ecs describe-services --cluster github-local-ecs-cluster --services github-local-ecs-service \
  --query 'services[0].events[0:5]'

# CloudWatchログでエラー詳細確認
aws logs filter-log-events --log-group-name /aws/lambda/github-local-lambda-api \
  --start-time $(date -d '1 hour ago' +%s)000
```

### デバッグ用コマンド

```bash
# 全リソースの状態確認
./scripts/check-infrastructure-status.sh

# CI/CDパイプライン実行状況確認
./scripts/check-pipeline-status.sh

# エンドポイント疎通確認
./scripts/test-all-endpoints.sh

# ログ一括確認
./scripts/collect-all-logs.sh
```

### サポート情報

問題が解決しない場合は、以下の情報を含めてIssueを作成してください：

1. 実行したコマンドとエラーメッセージ
2. AWS CLI設定（`aws configure list`）
3. 使用しているCI/CDツールとバージョン
4. CloudWatchログの関連部分
5. リソースの状態（`aws cloudformation describe-stacks`）

---

このガイドに従って設定することで、3つのCI/CDツールを同時に動作させ、それぞれの特徴と違いを比較検証できます。

# 技術スタック

## アプリケーション

### プログラミング言語・フレームワーク

- **Python**: 3.13
- **Webフレームワーク**: FastAPI
- **パッケージ管理**: uv

### API仕様

- **REST API**: FastAPIによる実装
- **API Gateway**: AWS API Gateway + Lambda統合

## インフラストラクチャ

### クラウドプロバイダー

- **AWS**: メインクラウドプラットフォーム

### Infrastructure as Code (IaC)

- **AWS CDK**: TypeScript/Python
- **AWS SAM**: Lambda関数のデプロイ

### コンピューティング

- **AWS Lambda**: サーバーレス実行環境
- **Amazon ECS**: コンテナオーケストレーション
- **Amazon EC2**: 仮想マシン

### コンテナ

- **Docker**: コンテナ化
- **Amazon ECR**: コンテナレジストリ

### ネットワーク・セキュリティ

- **Amazon VPC**: 仮想プライベートクラウド
- **AWS IAM**: アクセス管理
- **OIDC**: GitHub/GitLab - AWS間認証

## CI/CDツール

### パイプライン

- **GitHub Actions**: GitHubベースのCI/CD
- **GitLab CI/CD**: GitLabベースのCI/CD
- **AWS CodePipeline**: AWSネイティブCI/CD

### ビルド・テスト

- **AWS CodeBuild**: ビルドサービス
- **GitHub Actions Runners**: GitHubビルド環境
- **GitLab Runners**: GitLabビルド環境

### デプロイメント

- **AWS CodeDeploy**: Blue/Greenデプロイ（EC2）
- **Amazon ECS**: Blue/Greenデプロイ（コンテナ）
- **AWS SAM**: Lambdaデプロイ

## セキュリティ・品質管理

### 静的解析

- **Linting**: 各言語の標準ツール
- **Code Formatting**: 自動フォーマット

### セキュリティスキャン

- **SCA (Software Composition Analysis)**
  - AWS CodeGuru Security
  - GitHub Dependabot（GitHub）
  - GitLab Dependency Scanning（GitLab）

- **SAST (Static Application Security Testing)**
  - Amazon Inspector
  - GitHub CodeQL（GitHub）
  - GitLab SAST（GitLab）

### テスト

- **ユニットテスト**: pytest（Python）
- **テストカバレッジ**: coverage.py

## 開発・運用ツール

### バージョン管理

- **Git**: ソースコード管理
- **Conventional Commits**: コミットメッセージ規約

### 依存関係管理

- **uv**: Pythonパッケージ管理
- **npm**: Node.js依存関係（CDK用）

### キャッシュ

- **AWS CodeBuild Cache**: ビルドキャッシュ
- **GitHub Actions Cache**: アクションキャッシュ
- **GitLab CI Cache**: パイプラインキャッシュ

### 環境管理

- **asdf**: ランタイムバージョン管理
- **Docker**: 環境の標準化

## 監視・ログ

### ログ管理

- **Amazon CloudWatch**: AWSサービスログ
- **AWS X-Ray**: 分散トレーシング

### メトリクス

- **Amazon CloudWatch Metrics**: システムメトリクス
- **AWS Lambda Insights**: Lambda関数メトリクス

## 環境構成

### 環境分離

- **local**: ローカル開発環境
- **dev**: 開発環境
- **stg**: ステージング環境
- **prd**: 本番環境

### 設定管理

- **AWS Systems Manager Parameter Store**: 設定値管理
- **AWS Secrets Manager**: 機密情報管理

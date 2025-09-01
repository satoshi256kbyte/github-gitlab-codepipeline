# 設計文書

## 概要

GitHub Actions、GitLab CI/CD、AWS CodePipelineの3つのCI/CDツールを使用してPython FastAPIアプリケーションをAWS Lambda、ECS、EC2にデプロイするシステムの設計です。各ツールの特徴と実装方法の違いを比較検証できるサンプルシステムを構築します。

## アーキテクチャ

### 全体アーキテクチャ

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  GitHub Actions │    │   GitLab CI/CD  │    │  CodePipeline   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Static      │ │    │ │ Static      │ │    │ │ Static      │ │
│ │ Analysis    │ │    │ │ Analysis    │ │    │ │ Analysis    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Unit Tests  │ │    │ │ Unit Tests  │ │    │ │ Unit Tests  │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ SCA Check   │ │    │ │ SCA Check   │ │    │ │ SCA Check   │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ SAST Check  │ │    │ │ SAST Check  │ │    │ │ SAST Check  │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ GitHub Resources│    │ GitLab Resources│    │CodePipeline Res │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │github-local-│ │    │ │gitlab-local-│ │    │ │codepipeline-│ │
│ │lambda + API │ │    │ │lambda + API │ │    │ │local-lambda │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ │+ API        │ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ └─────────────┘ │
│ │github-local-│ │    │ │gitlab-local-│ │    │ ┌─────────────┐ │
│ │ecs + ALB    │ │    │ │ecs + ALB    │ │    │ │codepipeline-│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ │local-ecs    │ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ │+ ALB        │ │
│ │github-local-│ │    │ │gitlab-local-│ │    │ └─────────────┘ │
│ │ec2 + ALB    │ │    │ │ec2 + ALB    │ │    │ ┌─────────────┐ │
│ └─────────────┘ │    │ └─────────────┘ │    │ │codepipeline-│ │
└─────────────────┘    └─────────────────┘    │ │local-ec2    │ │
                                              │ │+ ALB        │ │
                                              │ └─────────────┘ │
                                              └─────────────────┘
```

### デプロイメント戦略

1. **AWS Lambda**: AWS SAMを使用したサーバーレスデプロイメント
2. **Amazon ECS**: ECSネイティブBlue/Greenデプロイメント
3. **Amazon EC2**: CodeDeployを使用したBlue/Greenデプロイメント

## コンポーネントと インターフェース

### 1. FastAPIアプリケーション

**場所**: `modules/api/`

**構成**:

- `main.py`: FastAPIアプリケーションのエントリーポイント
- `routers/`: APIエンドポイントの定義
- `models/`: データモデル
- `tests/`: ユニットテスト
- `requirements.txt`: 依存関係定義

**主要エンドポイント**:

- `GET /health`: ヘルスチェック
- `GET /version`: バージョン情報
- `GET /api/items`: アイテム一覧取得
- `POST /api/items`: アイテム作成
- `GET /api/items/{id}`: アイテム詳細取得

### 2. CI/CDパイプライン

#### GitHub Actions (`/.github/workflows/`)

**ワークフロー構成**:

- `ci.yml`: メインCI/CDワークフロー
- 並列実行ジョブ:
  - `lint`: 静的解析（ruff, black）
  - `test`: ユニットテスト（pytest）
  - `sca`: SCAチェック（Dependabot + CodeGuru Security）
  - `sast`: SASTチェック（CodeQL + CodeGuru Security）
- デプロイジョブ:
  - `deploy-lambda`: AWS SAMデプロイ
  - `deploy-ecs`: ECS Blue/Greenデプロイ
  - `deploy-ec2`: CodeDeploy Blue/Greenデプロイ

**認証**: GitHub OIDC Provider経由でAWS認証

#### GitLab CI/CD (`.gitlab-ci.yml`)

**パイプライン構成**:

- ステージ: `cache`, `check`, `deploy`
- 並列実行ジョブ:
  - `lint`: 静的解析
  - `test`: ユニットテスト
  - `sca`: SCAチェック（GitLab Dependency Scanning + CodeGuru Security）
  - `sast`: SASTチェック（GitLab SAST + CodeGuru Security）
- デプロイジョブ: Lambda、ECS、EC2への並列デプロイ

**認証**: GitLab CI/CD変数でAWS認証情報管理

#### AWS CodePipeline (`codepipeline/`)

**パイプライン構成**:

- ソース: GitHub連携
- ビルド: CodeBuildプロジェクト
  - `cache-build`: 依存関係キャッシュ作成
  - `lint-build`: 静的解析
  - `test-build`: ユニットテスト
  - `sca-build`: CodeGuru Securityスキャン
  - `sast-build`: Amazon Inspectorスキャン
- デプロイ: Lambda、ECS、EC2への並列デプロイ

**認証**: CodePipelineサービスロール

### 3. AWSインフラストラクチャ

#### AWS CDK構成 (`cdk/`)

**スタック構成**:

- `NetworkStack`: 共有VPC、サブネット、セキュリティグループ
- `GitHubLambdaStack`: GitHub Actions用Lambda関数、API Gateway
- `GitLabLambdaStack`: GitLab CI/CD用Lambda関数、API Gateway
- `CodePipelineLambdaStack`: CodePipeline用Lambda関数、API Gateway
- `GitHubEcsStack`: GitHub Actions用ECSクラスター、サービス、ALB
- `GitLabEcsStack`: GitLab CI/CD用ECSクラスター、サービス、ALB
- `CodePipelineEcsStack`: CodePipeline用ECSクラスター、サービス、ALB
- `GitHubEc2Stack`: GitHub Actions用EC2インスタンス、ALB、CodeDeployアプリケーション
- `GitLabEc2Stack`: GitLab CI/CD用EC2インスタンス、ALB、CodeDeployアプリケーション
- `CodePipelineEc2Stack`: CodePipeline用EC2インスタンス、ALB、CodeDeployアプリケーション
- `PipelineStack`: CodePipeline、CodeBuildプロジェクト
- `IamStack`: 必要なIAMロール（Admin権限）

**リソース命名規約**:

各CI/CDツール専用のリソースを作成し、同時実行で違いを比較できるようにします：

- **GitHub Actions用**: `github-local-{リソース種類}-{用途}-{連番}`
- **GitLab CI/CD用**: `gitlab-local-{リソース種類}-{用途}-{連番}`  
- **CodePipeline用**: `codepipeline-local-{リソース種類}-{用途}-{連番}`

**共有リソース**: `shared-local-{リソース種類}-{用途}-{連番}`（VPC、サブネットなど）

#### ネットワーク設計

```
共有VPC (10.0.0.0/16)
├── Public Subnet A (10.0.1.0/24) - AZ-a
├── Public Subnet B (10.0.2.0/24) - AZ-b  
├── Private Subnet A (10.0.11.0/24) - AZ-a
└── Private Subnet B (10.0.12.0/24) - AZ-b

各CI/CDツール専用リソース:
├── GitHub Actions ALB: Public Subnets (Port 8080)
├── GitLab CI/CD ALB: Public Subnets (Port 8081)  
├── CodePipeline ALB: Public Subnets (Port 8082)
├── 各ECS Tasks: Private Subnets
└── 各EC2 Instances: Private Subnets

API Gateway: 各CI/CDツール専用のAPI Gateway
```

## データモデル

### APIレスポンスモデル

```python
# ヘルスチェック
class HealthResponse(BaseModel):
    status: str = "healthy"
    timestamp: datetime

# バージョン情報
class VersionResponse(BaseModel):
    version: str
    build_time: datetime
    commit_hash: str

# アイテムモデル
class Item(BaseModel):
    id: int
    name: str
    description: str
    created_at: datetime

class ItemCreate(BaseModel):
    name: str
    description: str
```

### 設定管理

```python
class Settings(BaseModel):
    app_name: str = "CI/CD Comparison API"
    version: str = "1.0.0"
    environment: str = "local"
    log_level: str = "INFO"
```

## エラーハンドリング

### パイプライン失敗条件

各CI/CDツールで統一された失敗条件:

1. **静的解析失敗**: ruff、blackでのコード品質チェック失敗
2. **ユニットテスト失敗**: pytestでのテスト失敗
3. **SCA脆弱性発見**: 依存関係の脆弱性検出
4. **SAST脆弱性発見**: ソースコードの脆弱性検出

### APIエラーハンドリング

```python
# HTTPエラーレスポンス
class ErrorResponse(BaseModel):
    error: str
    message: str
    timestamp: datetime

# 共通エラーハンドラー
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=exc.detail,
            message="HTTP error occurred",
            timestamp=datetime.utcnow()
        ).dict()
    )
```

### デプロイメントエラーハンドリング

- **Lambda**: SAMデプロイ失敗時の自動ロールバック
- **ECS**: Blue/Greenデプロイ失敗時の自動ロールバック
- **EC2**: CodeDeployでの自動ロールバック設定

## テスト戦略

### ユニットテスト

**フレームワーク**: pytest + pytest-asyncio

**テスト構成**:

```
tests/
├── test_main.py          # メインアプリケーションテスト
├── test_routers/         # ルーターテスト
│   ├── test_health.py
│   ├── test_version.py
│   └── test_items.py
├── test_models.py        # データモデルテスト
└── conftest.py          # テスト設定
```

**カバレッジ目標**: 80%以上

### 統合テスト

各デプロイ先での基本的な動作確認:

- ヘルスチェックエンドポイントの応答確認
- 基本的なCRUD操作の動作確認

### ローカルテスト環境

#### GitHub Actions

- **ツール**: act
- **設定**: `.actrc`でローカル実行設定
- **制限**: 一部のAWSサービス連携は模擬実行

#### GitLab CI/CD

- **ツール**: GitLab Runner（Docker executor）
- **設定**: `.gitlab-runner/config.toml`
- **制限**: AWS認証情報の安全な管理が必要

### セキュリティテスト

#### SCAツール比較

- **GitHub**: Dependabot + CodeGuru Security
- **GitLab**: Dependency Scanning + CodeGuru Security  
- **CodePipeline**: CodeGuru Security

#### SASTツール比較

- **GitHub**: CodeQL + CodeGuru Security
- **GitLab**: GitLab SAST + CodeGuru Security
- **CodePipeline**: Amazon Inspector

## 実装の考慮事項

### パフォーマンス最適化

1. **キャッシュ戦略**:
   - GitHub Actions: actions/cache
   - GitLab CI/CD: cache設定
   - CodePipeline: CodeBuildキャッシュ

2. **並列実行**:
   - チェック工程の並列実行でパイプライン時間短縮
   - 3つのCI/CDツールの同時実行による比較検証

### コスト最適化

1. **EC2インスタンス**: t4g.micro使用（各CI/CDツール用に3台）
2. **ECS**: Fargateスポットインスタンス使用検討（各CI/CDツール用に3クラスター）
3. **Lambda**: ARM64アーキテクチャ使用（各CI/CDツール用に3関数）
4. **リソース分離**: 各CI/CDツール専用リソースによる影響範囲の明確化

### 運用性

1. **ログ管理**: CloudWatch Logsへの統一ログ出力（CI/CDツール別にロググループ分離）
2. **デプロイ履歴**: 各ツールでのデプロイ履歴管理と比較
3. **ロールバック**: 各デプロイ方式での迅速なロールバック機能
4. **モニタリング**: 各CI/CDツールのパフォーマンス比較用メトリクス

### セキュリティ

1. **認証**: 各CI/CDツールでの安全なAWS認証
2. **権限**: サンプル用途のためAdmin権限使用
3. **脆弱性管理**: 複数ツールでの脆弱性検出と比較
4. **リソース分離**: 各CI/CDツール専用リソースによるセキュリティ境界の明確化

### CI/CDツール比較の観点

1. **デプロイ速度**: 各ツールのパイプライン実行時間比較
2. **設定の複雑さ**: YAML設定ファイルの記述量と複雑さ比較
3. **エラーハンドリング**: 失敗時の挙動とログ出力の違い
4. **キャッシュ効率**: 各ツールのキャッシュ機能の効果比較
5. **セキュリティスキャン**: 各ツール固有のセキュリティ機能比較
6. **AWS統合**: AWSサービスとの統合の容易さ比較

# CloudWatch ログ管理設定

## 概要

このドキュメントでは、CI/CDツール比較プロジェクトにおけるCloudWatchログの設定と管理方法について説明します。各CI/CDツール（GitHub Actions、GitLab CI/CD、AWS CodePipeline）専用のログ グループが作成され、相互に分離された状態でログが管理されます。

## ログ グループ構成

### 命名規約

各CI/CDツール専用のログ グループは以下の命名規約に従います：

```
/{service}/{cicd-tool}-{environment}-{resource-type}-{purpose}
```

### ログ グループ一覧

#### GitHub Actions用ログ グループ

| サービス | ログ グループ名 | 用途 | 保持期間 |
|---------|----------------|------|----------|
| Lambda | `/aws/lambda/github-local-lambda-api` | Lambda関数のアプリケーションログ | 1週間 |
| API Gateway | `/aws/apigateway/github-local-apigw-access` | API Gatewayアクセスログ | 1週間 |
| ECS | `/ecs/github-local-ecs-application` | ECSアプリケーションログ | 1週間 |
| ECS | `/ecs/github-local-ecs-system` | ECSシステムログ | 3日間 |
| EC2 | `/ec2/github-local-ec2-application` | EC2アプリケーションログ | 1週間 |
| EC2 | `/ec2/github-local-ec2-system` | EC2システムログ | 3日間 |
| EC2 | `/ec2/github-local-ec2-codedeploy` | CodeDeployログ | 3日間 |

#### GitLab CI/CD用ログ グループ

| サービス | ログ グループ名 | 用途 | 保持期間 |
|---------|----------------|------|----------|
| Lambda | `/aws/lambda/gitlab-local-lambda-api` | Lambda関数のアプリケーションログ | 1週間 |
| API Gateway | `/aws/apigateway/gitlab-local-apigw-access` | API Gatewayアクセスログ | 1週間 |
| ECS | `/ecs/gitlab-local-ecs-application` | ECSアプリケーションログ | 1週間 |
| ECS | `/ecs/gitlab-local-ecs-system` | ECSシステムログ | 3日間 |
| EC2 | `/ec2/gitlab-local-ec2-application` | EC2アプリケーションログ | 1週間 |
| EC2 | `/ec2/gitlab-local-ec2-system` | EC2システムログ | 3日間 |
| EC2 | `/ec2/gitlab-local-ec2-codedeploy` | CodeDeployログ | 3日間 |

#### AWS CodePipeline用ログ グループ

| サービス | ログ グループ名 | 用途 | 保持期間 |
|---------|----------------|------|----------|
| Lambda | `/aws/lambda/codepipeline-local-lambda-api` | Lambda関数のアプリケーションログ | 1週間 |
| API Gateway | `/aws/apigateway/codepipeline-local-apigw-access` | API Gatewayアクセスログ | 1週間 |
| ECS | `/ecs/codepipeline-local-ecs-application` | ECSアプリケーションログ | 1週間 |
| ECS | `/ecs/codepipeline-local-ecs-system` | ECSシステムログ | 3日間 |
| EC2 | `/ec2/codepipeline-local-ec2-application` | EC2アプリケーションログ | 1週間 |
| EC2 | `/ec2/codepipeline-local-ec2-system` | EC2システムログ | 3日間 |
| EC2 | `/ec2/codepipeline-local-ec2-codedeploy` | CodeDeployログ | 3日間 |

## ログ設定の実装

### CDKでのログ グループ作成

各スタックでCloudWatchログ グループが自動的に作成されます：

```typescript
// Lambda Stack
const logGroup = new logs.LogGroup(this, 'LambdaLogGroup', {
    logGroupName: `/aws/lambda/${resourcePrefix}-lambda-api`,
    retention: logs.RetentionDays.ONE_WEEK,
    removalPolicy: cdk.RemovalPolicy.DESTROY,
});

// ECS Stack
const applicationLogGroup = new logs.LogGroup(this, 'ApplicationLogGroup', {
    logGroupName: `/ecs/${resourcePrefix}-ecs-application`,
    retention: logs.RetentionDays.ONE_WEEK,
    removalPolicy: cdk.RemovalPolicy.DESTROY,
});

// EC2 Stack
const applicationLogGroup = new logs.LogGroup(this, 'ApplicationLogGroup', {
    logGroupName: `/ec2/${resourcePrefix}-ec2-application`,
    retention: logs.RetentionDays.ONE_WEEK,
    removalPolicy: cdk.RemovalPolicy.DESTROY,
});
```

### ログ設定のベストプラクティス

#### アプリケーションログ

```json
{
    "timestamp": "2024-01-01T12:00:00.000Z",
    "level": "INFO",
    "message": "Request processed successfully",
    "requestId": "abc123",
    "cicdTool": "github",
    "method": "GET",
    "path": "/api/items",
    "statusCode": 200,
    "responseTime": 150
}
```

#### システムログ

```json
{
    "timestamp": "2024-01-01T12:00:00.000Z",
    "level": "WARN",
    "message": "High memory usage detected",
    "source": "system-monitor",
    "memoryUsage": 85.5
}
```

## ログ分析ツール

### CloudWatch ログ分析スクリプト

プロジェクトには包括的なログ分析スクリプトが含まれています：

```bash
# ログ グループ一覧を表示
./scripts/cloudwatch-log-analysis.sh list-log-groups

# 特定のCI/CDツールのログを取得
./scripts/cloudwatch-log-analysis.sh get-recent-logs --cicd-tool github --log-type lambda

# エラーログのみを取得
./scripts/cloudwatch-log-analysis.sh get-error-logs --start-time "2024-01-01T00:00:00Z"

# パフォーマンス比較レポートを生成
./scripts/cloudwatch-log-analysis.sh compare-performance --output-dir ./reports

# リアルタイムログ監視
./scripts/cloudwatch-log-analysis.sh tail-logs --cicd-tool gitlab --log-type ecs-app
```

### 利用可能なコマンド

| コマンド | 説明 | 例 |
|---------|------|-----|
| `list-log-groups` | CI/CDツール別のログ グループ一覧を表示 | `--cicd-tool github` |
| `get-recent-logs` | 最近のログを取得（デフォルト: 1時間） | `--log-type lambda --format json` |
| `get-error-logs` | エラーログのみを取得 | `--start-time "2024-01-01T00:00:00Z"` |
| `compare-performance` | パフォーマンス比較レポートを生成 | `--output-dir ./reports` |
| `export-logs` | ログをファイルにエクスポート | `--format csv --output-dir ./exports` |
| `tail-logs` | リアルタイムでログを監視 | `--cicd-tool github --log-type lambda` |

## CloudWatch ダッシュボード

### 監視ダッシュボード

CI/CDツール比較用のCloudWatchダッシュボードが自動的に作成されます：

- **エラー率比較**: 各CI/CDツールのエラー発生率を比較
- **レスポンス時間比較**: 各デプロイ先のレスポンス時間を比較
- **ログ インサイト**: 横断的なログ検索とクエリ

### メトリクスフィルター

各ログ グループには以下のメトリクスフィルターが設定されます：

#### エラー監視

```
ERROR Exception error
```

#### レスポンス時間監視

```
$.responseTime
```

## ログ監視とアラート

### 推奨アラート設定

#### 高エラー率アラート

```typescript
new cloudwatch.Alarm(this, 'HighErrorRateAlarm', {
    metric: errorMetricFilter.metric({
        statistic: 'Sum',
        period: cdk.Duration.minutes(5),
    }),
    threshold: 10,
    evaluationPeriods: 2,
    treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
});
```

#### 高レスポンス時間アラート

```typescript
new cloudwatch.Alarm(this, 'HighLatencyAlarm', {
    metric: latencyMetricFilter.metric({
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
    }),
    threshold: 5000, // 5秒
    evaluationPeriods: 3,
    treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
});
```

## ログ検索クエリ例

### CloudWatch Logs Insights クエリ

#### エラー分析

```sql
fields @timestamp, @message, @logStream
| filter @message like /ERROR/ or @message like /Exception/
| sort @timestamp desc
| limit 100
```

#### パフォーマンス分析

```sql
fields @timestamp, @message
| filter @message like /Request processed/
| parse @message "responseTime: *" as responseTime
| stats avg(responseTime), max(responseTime), min(responseTime) by bin(5m)
| sort @timestamp desc
```

#### CI/CDツール別リクエスト統計

```sql
fields @timestamp, @message
| filter @message like /Request received/
| parse @logStream "*" as cicdTool
| stats count() by cicdTool, bin(1h)
| sort @timestamp desc
```

## トラブルシューティング

### よくある問題

#### ログ グループが見つからない

```bash
# ログ グループの存在確認
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/github-local"

# CDKスタックの確認
cdk list
cdk diff github-cicd-comparison-local-stack-lambda
```

#### ログが出力されない

1. **IAMロールの確認**: Lambda/ECS/EC2のロールにCloudWatchログ書き込み権限があることを確認
2. **ログ設定の確認**: アプリケーションのログ設定が正しいことを確認
3. **ネットワーク設定の確認**: プライベートサブネットからCloudWatchへのアクセスが可能であることを確認

#### パフォーマンスが悪い

1. **ログ レベルの調整**: 不要なDEBUGログを無効化
2. **バッチ処理**: ログの一括送信を有効化
3. **フィルタリング**: 必要なログのみを送信

## セキュリティ考慮事項

### ログデータの保護

- **機密情報のマスキング**: パスワードやAPIキーなどの機密情報をログに出力しない
- **アクセス制御**: ログ グループへのアクセスをIAMで適切に制限
- **暗号化**: CloudWatchログの暗号化を有効化（必要に応じて）

### コンプライアンス

- **データ保持**: 法的要件に応じてログ保持期間を調整
- **監査ログ**: 重要な操作のログを確実に記録
- **データ所在地**: ログデータの保存場所を適切に管理

## コスト最適化

### ログコスト削減

1. **保持期間の最適化**: 不要なログの保持期間を短縮
2. **ログ レベルの調整**: 本番環境では INFO レベル以上のみ出力
3. **サンプリング**: 高頻度ログのサンプリング実装
4. **アーカイブ**: 古いログのS3アーカイブ

### 監視コスト

- **メトリクスフィルター**: 必要最小限のメトリクスフィルターのみ作成
- **ダッシュボード**: 使用頻度の低いダッシュボードは削除
- **アラーム**: 重要なアラームのみ設定

## 参考資料

- [AWS CloudWatch Logs ユーザーガイド](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [CloudWatch Logs Insights クエリ構文](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS CDK CloudWatch Logs コンストラクト](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_logs-readme.html)

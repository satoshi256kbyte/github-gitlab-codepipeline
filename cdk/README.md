# CI/CD Pipeline Comparison - CDK Infrastructure

このディレクトリには、CI/CDパイプライン比較プロジェクトのAWS CDKインフラストラクチャコードが含まれています。

## 概要

以下のAWSリソースを作成します：

- **NetworkStack**: VPC、サブネット、セキュリティグループ
- **IamStack**: 各サービス用のIAMロール
- **LambdaStack**: Lambda関数とAPI Gateway
- **EcsStack**: ECSクラスター、サービス、ALB
- **Ec2Stack**: EC2インスタンス、ALB、CodeDeployアプリケーション
- **PipelineStack**: CodePipeline（オプション）

## 前提条件

- Node.js 18以上
- AWS CLI設定済み
- AWS CDK CLI (`npm install -g aws-cdk`)

## セットアップ

```bash
# 依存関係のインストール
npm install

# TypeScriptコンパイル
npm run build

# CDKブートストラップ（初回のみ）
cdk bootstrap

# スタックのデプロイ
cdk deploy --all
```

## 環境設定

`cdk.context.json`で以下の設定を変更できます：

- `environment`: デプロイ環境（local/dev/stg/prd）
- `enableCodePipeline`: CodePipelineスタックの有効化
- `enableGitHubOidc`: GitHub OIDC接続の有効化

## リソース命名規約

`{サービス名}-{環境名}-{AWSリソース種類}-{用途}-{連番}`

例：`cicd-comparison-local-vpc-main`

## 利用可能なコマンド

```bash
# ビルド
npm run build

# 監視モード
npm run watch

# テスト
npm run test

# リント
npm run lint

# CDKコマンド
npm run cdk -- <command>
```

## スタック依存関係

1. IamStack（他のスタックで使用するロールを作成）
2. NetworkStack（VPCとネットワーク設定）
3. LambdaStack、EcsStack、Ec2Stack（並列デプロイ可能）
4. PipelineStack（オプション）

## 注意事項

- サンプル用途のため、IAMロールにAdmin権限を付与しています
- 本番環境では最小権限の原則に従ってください
- EC2インスタンスはt4g.microを使用してコストを最適化しています

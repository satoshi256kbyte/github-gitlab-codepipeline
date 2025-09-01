# GitHub Actions OIDC認証設定ガイド

## 概要

GitHub ActionsからAWSリソースにアクセスするためのOIDC（OpenID Connect）認証を設定します。これにより、長期的なアクセスキーを使用せずに、安全にAWSサービスにアクセスできます。

## 前提条件

- AWS CDKがインストールされていること
- 適切なAWS権限を持つアカウントでログインしていること
- GitHubリポジトリが作成されていること

## 設定手順

### 1. GitHub OIDC Providerとロールの作成

CDKを使用してGitHub OIDC ProviderとIAMロールを作成します：

```bash
# GitHub OIDC設定を有効化してデプロイ
cd cdk
npx cdk deploy --context enableGitHubOidc=true \
  --context githubOrg=your-github-org \
  --context githubRepo=your-repo-name
```

### 2. 環境変数の設定

デプロイ後、出力されるロールARNをGitHubリポジトリのSecretsに設定します：

1. GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」に移動
2. 「New repository secret」をクリック
3. 以下のシークレットを追加：

| Name | Value |
|------|-------|
| `AWS_ROLE_ARN` | CDKデプロイ時に出力されるロールARN |

### 3. GitHub Actionsワークフローでの使用

ワークフローファイル（`.github/workflows/ci.yml`）では、以下のように設定されています：

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

### 4. 権限の設定

各ジョブで必要な権限を設定：

```yaml
permissions:
  id-token: write  # OIDC認証に必要
  contents: read   # リポジトリ内容の読み取り
  security-events: write  # セキュリティイベントの書き込み（CodeQL用）
```

## セキュリティ考慮事項

### 1. 最小権限の原則

現在の設定では、サンプル用途のため`AdministratorAccess`を付与していますが、本番環境では必要最小限の権限のみを付与してください。

### 2. ブランチ制限

OIDC設定では、以下のブランチからのみアクセスを許可しています：

- `main`ブランチ
- `develop`ブランチ
- プルリクエスト

### 3. リポジトリ制限

指定されたGitHubオーガニゼーションとリポジトリからのみアクセスを許可しています。

## トラブルシューティング

### 1. 認証エラー

```
Error: Could not assume role with OIDC
```

**解決方法：**

- ロールARNが正しく設定されているか確認
- GitHubオーガニゼーション名とリポジトリ名が正しいか確認
- ブランチ名が許可されているか確認

### 2. 権限エラー

```
Error: User is not authorized to perform action
```

**解決方法：**

- IAMロールに必要な権限が付与されているか確認
- リソースへのアクセス権限があるか確認

### 3. OIDC Provider設定エラー

```
Error: No OpenIDConnect provider found
```

**解決方法：**

- CDKデプロイが正常に完了しているか確認
- OIDC Providerが作成されているかAWSコンソールで確認

## 参考資料

- [GitHub Actions - Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM - Creating OpenID Connect identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)

## 設定例

### CDKコンテキスト設定例

```json
{
  "enableGitHubOidc": "true",
  "githubOrg": "your-organization",
  "githubRepo": "cicd-pipeline-comparison",
  "environment": "local"
}
```

### GitHub Secrets設定例

```
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/cicd-comparison-local-github-actions-role
```

## 注意事項

1. **初回設定時**: CDKデプロイ前にGitHub Actionsを実行しないでください
2. **ロール変更時**: ロールARNが変更された場合は、GitHubのSecretsも更新してください
3. **権限変更時**: IAMロールの権限を変更した場合は、CDKを再デプロイしてください

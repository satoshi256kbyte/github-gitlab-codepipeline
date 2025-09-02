# GitHub Actions ローカルテスト環境

GitHub Actionsワークフローをローカル環境でテストするためのガイドです。

## 概要

`act`ツールを使用してGitHub Actionsワークフローをローカルで実行し、クラウド環境にデプロイする前に動作を確認できます。

## 前提条件

### 必要なツール

1. **Docker**: コンテナ実行環境
2. **act**: GitHub Actionsローカル実行ツール
3. **Git**: バージョン管理

### インストール方法

#### macOS (Homebrew)

```bash
# actツールのインストール
brew install act

# Dockerのインストール（Docker Desktopを推奨）
brew install --cask docker
```

#### Linux

```bash
# actツールのインストール
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Dockerのインストール（Ubuntu/Debian）
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

#### Windows

```powershell
# Chocolateyを使用
choco install act-cli
choco install docker-desktop

# または、Scoopを使用
scoop install act
```

## 設定ファイル

### .actrc

プロジェクトルートの`.actrc`ファイルでactツールの基本設定を行います。

```bash
# デフォルトプラットフォーム
-P ubuntu-latest=catthehacker/ubuntu:act-latest

# 環境変数ファイル
--env-file .env.local

# 詳細ログ
--verbose
```

### .env.local

ローカル実行用の環境変数を設定します。

```bash
# AWS設定
AWS_DEFAULT_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012

# サービス設定
SERVICE_NAME=cicd-comparison
STAGE_NAME=local

# ローカルテスト用フラグ
LOCAL_TEST=true
SKIP_AWS_DEPLOY=true
```

## 使用方法

### 基本的な実行

```bash
# 全ワークフローの実行
act

# 特定のワークフローファイルの実行
act -W .github/workflows/ci.yml

# 特定のイベントでの実行
act push
act pull_request
```

### 便利なスクリプトの使用

プロジェクトに含まれる`scripts/test-github-actions.sh`スクリプトを使用すると、より簡単にテストできます。

```bash
# スクリプトに実行権限を付与
chmod +x scripts/test-github-actions.sh

# 使用方法の確認
./scripts/test-github-actions.sh --help

# 全ワークフローの実行
./scripts/test-github-actions.sh

# 特定のワークフローの実行
./scripts/test-github-actions.sh ci.yml

# 特定のジョブのみ実行
./scripts/test-github-actions.sh --job lint

# ドライラン（実際には実行しない）
./scripts/test-github-actions.sh --dry-run

# 利用可能なワークフロー一覧
./scripts/test-github-actions.sh --list
```

### 高度な使用方法

#### 特定のジョブのみ実行

```bash
# lintジョブのみ実行
act -j lint

# testジョブのみ実行
act -j test
```

#### 環境変数の上書き

```bash
# 特定の環境変数を設定して実行
act -s AWS_DEFAULT_REGION=ap-northeast-1 -s STAGE_NAME=dev
```

#### ボリュームマウント

```bash
# ローカルディレクトリをマウント
act --bind
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. Dockerイメージのダウンロードが遅い

```bash
# 軽量なイメージを使用
act -P ubuntu-latest=node:16-alpine
```

#### 2. AWS認証エラー

ローカルテスト時はAWSデプロイをスキップするように設定：

```bash
# .env.localに追加
SKIP_AWS_DEPLOY=true
LOCAL_TEST=true
```

#### 3. メモリ不足エラー

```bash
# Dockerのメモリ制限を増やす
# Docker Desktop > Settings > Resources > Memory
```

#### 4. ネットワーク接続エラー

```bash
# ホストネットワークを使用
act --use-gitignore=false
```

### ログの確認

```bash
# 詳細ログで実行
act --verbose

# 特定のステップのログを確認
act --verbose | grep "step_name"
```

## 制限事項

### actツールの制限

1. **GitHub固有の機能**: 一部のGitHub固有の機能は模擬実行
2. **シークレット**: GitHub Secretsは環境変数ファイルで代替
3. **外部サービス**: 実際のAWSサービスへの接続は制限される場合がある
4. **並列実行**: 一部の並列実行が正しく動作しない場合がある

### 推奨される使用方法

1. **構文チェック**: ワークフローファイルの構文確認
2. **ロジックテスト**: 基本的なスクリプトロジックの確認
3. **環境変数テスト**: 環境変数の設定と参照の確認
4. **依存関係テスト**: パッケージインストールの確認

## ベストプラクティス

### 1. 段階的テスト

```bash
# 1. 構文チェック
act --dry-run

# 2. 特定のジョブテスト
act -j lint

# 3. 全体テスト
act
```

### 2. 環境分離

```bash
# 開発用設定
cp .env.local .env.dev
# 本番用設定
cp .env.local .env.prod
```

### 3. キャッシュ活用

```bash
# Dockerイメージのキャッシュ
docker system prune -f
act --pull=false
```

### 4. ログ管理

```bash
# ログファイルに出力
act --verbose > act-test.log 2>&1
```

## 参考資料

- [act公式ドキュメント](https://github.com/nektos/act)
- [GitHub Actions公式ドキュメント](https://docs.github.com/ja/actions)
- [Docker公式ドキュメント](https://docs.docker.com/)

## サポート

問題が発生した場合は、以下を確認してください：

1. actツールのバージョン: `act --version`
2. Dockerの状態: `docker info`
3. ワークフローファイルの構文: `act --dry-run`
4. 環境変数の設定: `.env.local`ファイルの内容

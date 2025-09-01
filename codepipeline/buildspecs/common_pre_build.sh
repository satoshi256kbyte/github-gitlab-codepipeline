#!/bin/bash
# 共通プリビルドスクリプト
# ビルド前の環境設定を行う

set -e

echo "=== 共通プリビルド開始 ==="

# 環境変数の設定
export PATH="$HOME/.asdf/bin:$HOME/.cargo/bin:$PATH"
source ~/.asdf/asdf.sh

# 開発依存関係を含むかどうかのフラグ
INCLUDE_DEV=${1:-""}

echo "現在のディレクトリ: $(pwd)"
echo "Python バージョン: $(python --version 2>/dev/null || echo 'Python not found')"
echo "uv バージョン: $(uv --version 2>/dev/null || echo 'uv not found')"
echo "AWS CLI バージョン: $(aws --version 2>/dev/null || echo 'AWS CLI not found')"

# Python仮想環境の作成と依存関係のインストール
if [ -f "pyproject.toml" ]; then
    echo "Python依存関係をインストール中..."
    if [ "$INCLUDE_DEV" = "--dev" ]; then
        echo "開発依存関係も含めてインストール..."
        uv sync --dev
    else
        echo "本番依存関係のみインストール..."
        uv sync --no-dev
    fi
fi

# Node.js依存関係のインストール（CDK用）
if [ -f "cdk/package.json" ]; then
    echo "CDK Node.js依存関係をインストール中..."
    cd cdk
    npm ci
    cd ..
fi

# 環境変数の確認
echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-'未設定'}"
echo "AWS_ACCOUNT_ID: ${AWS_ACCOUNT_ID:-'未設定'}"
echo "SERVICE_NAME: ${SERVICE_NAME:-'未設定'}"
echo "STAGE_NAME: ${STAGE_NAME:-'未設定'}"

echo "=== 共通プリビルド完了 ==="
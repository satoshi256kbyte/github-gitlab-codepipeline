#!/bin/bash
# 共通環境変数設定スクリプト
# 各buildspecファイルで共通して使用する環境変数を設定

# PATH設定
export PATH="$HOME/.asdf/bin:$HOME/.cargo/bin:$PATH"

# asdfの読み込み
if [ -f "$HOME/.asdf/asdf.sh" ]; then
    source ~/.asdf/asdf.sh
fi

# AWS関連の環境変数
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-ap-northeast-1}
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# プロジェクト関連の環境変数
export SERVICE_NAME=${SERVICE_NAME:-cicd-comparison}
export STAGE_NAME=${STAGE_NAME:-local}

# Python関連の環境変数
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
export UV_CACHE_DIR="$HOME/.cache/uv"

echo "環境変数設定完了:"
echo "  AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
echo "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "  SERVICE_NAME: $SERVICE_NAME"
echo "  STAGE_NAME: $STAGE_NAME"
echo "  PYTHONPATH: $PYTHONPATH"
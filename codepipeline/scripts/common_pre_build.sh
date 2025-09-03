#!/bin/bash
set -e

echo "=== Common Pre-Build Phase ==="

# パラメータ解析
INSTALL_DEV_DEPS=false
SKIP_PYTHON=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      INSTALL_DEV_DEPS=true
      shift
      ;;
    --skip-python)
      SKIP_PYTHON=true
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# 共通環境変数設定を読み込み
. "$(dirname "$0")/common_env.sh"

# 依存関係のインストール
echo "Installing dependencies..."
if [ "$SKIP_PYTHON" = false ]; then
  if [ "$INSTALL_DEV_DEPS" = true ]; then
    uv sync --dev
  else
    uv sync
  fi
fi
npm ci

echo "=== Common Pre-Build Phase Completed ==="

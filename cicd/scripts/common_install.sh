#!/bin/bash
set -e

echo "=== Common Install Phase ==="

# パラメータ解析
SKIP_PYTHON=false
while [[ $# -gt 0 ]]; do
  case $1 in
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

# システム依存関係のインストール
echo "Installing system dependencies..."
# apt-get update
apt-get install -y curl libbz2-dev libreadline-dev liblzma-dev zlib1g-dev libffi-dev libssl-dev unzip

# asdfのインストール（キャッシュを活用、整合性チェック付き）
echo "Installing asdf..."
if [ ! -d "$HOME/.asdf" ] || [ ! -f "$HOME/.asdf/asdf.sh" ]; then
  echo "Installing or reinstalling asdf..."
  rm -rf "$HOME/.asdf"
  git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.14.0
else
  echo "asdf already installed and valid - CACHE HIT!"
fi

export ASDF_DIR="$HOME/.asdf"
. "$ASDF_DIR/asdf.sh"

# プラグインの追加
echo "Adding asdf plugins..."
asdf plugin add python || true
asdf plugin add aws-sam-cli || true

# 必要なツールのインストール
echo "Installing tools via asdf..."
asdf install

# uvのインストール（Pythonが必要な場合のみ）
if [ "$SKIP_PYTHON" = false ]; then
  echo "Installing uv..."
  if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source "$HOME/.cargo/env" 2>/dev/null || true
  fi
else
  echo "Skipping uv installation as Python is not needed"
fi

echo "=== Common Install Phase Completed ==="

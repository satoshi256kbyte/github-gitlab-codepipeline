#!/bin/bash
# 共通環境変数設定スクリプト

export ASDF_DIR="$HOME/.asdf"
. "$ASDF_DIR/asdf.sh"

# 直接インストールしたツールのパスを追加
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# デバッグ用：パスの確認
echo "Environment setup completed:"
echo "  PATH: $PATH"
echo "  uv: $(which uv || echo 'not found')"
echo "  python: $(which python || echo 'not found')"
echo "  node: $(which node || echo 'not found')"
echo "  rain: $(which rain || echo 'not found')"

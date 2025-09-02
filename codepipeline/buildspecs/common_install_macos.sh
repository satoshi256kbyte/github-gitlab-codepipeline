#!/bin/bash
# macOS用共通インストールスクリプト
# ローカル開発環境で使用する共通のパッケージとツールをインストールする

set -e

echo "=== macOS用共通インストール開始 ==="

# Homebrewがインストールされているか確認
if ! command -v brew &> /dev/null; then
    echo "Homebrewがインストールされていません。Homebrewをインストールしてください。"
    echo "https://brew.sh/"
    exit 1
fi

# 必要なパッケージのインストール
echo "必要なパッケージをインストール中..."
brew install curl wget jq git || true

# asdfがインストールされているか確認
if ! command -v asdf &> /dev/null; then
    echo "asdfをインストール中..."
    brew install asdf || true
fi

# asdfの環境設定
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
    source /opt/homebrew/opt/asdf/libexec/asdf.sh
elif [ -f "/usr/local/opt/asdf/libexec/asdf.sh" ]; then
    source /usr/local/opt/asdf/libexec/asdf.sh
elif [ -f "$HOME/.asdf/asdf.sh" ]; then
    source ~/.asdf/asdf.sh
fi

# Pythonプラグインの追加
echo "asdf Pythonプラグインを追加中..."
asdf plugin add python || true

# Node.jsプラグインの追加（CDK用）
echo "asdf Node.jsプラグインを追加中..."
asdf plugin add nodejs || true

# .tool-versionsファイルが存在する場合、指定されたバージョンをインストール
if [ -f ".tool-versions" ]; then
    echo ".tool-versionsからランタイムをインストール中..."
    asdf install || true
    asdf reshim || true
fi

# uvがインストールされているか確認
if ! command -v uv &> /dev/null; then
    echo "uvをインストール中..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# AWS CLIがインストールされているか確認
if ! command -v aws &> /dev/null; then
    echo "AWS CLIをインストール中..."
    brew install awscli || true
fi

# SAM CLIがインストールされているか確認
if ! command -v sam &> /dev/null; then
    echo "AWS SAM CLIをインストール中..."
    brew install aws-sam-cli || true
fi

echo "=== macOS用共通インストール完了 ==="
#!/bin/bash
# 共通インストールスクリプト
# 必要なツールとランタイムをインストールする

set -e

echo "=== 共通インストール開始 ==="

# システムパッケージの更新
apt-get update

# 必要なパッケージのインストール
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    lsb-release

# asdfのインストール
echo "asdfをインストール中..."
if [ ! -d "$HOME/.asdf" ]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
fi

# asdfの環境設定を永続化
export PATH="$HOME/.asdf/bin:$HOME/.cargo/bin:$PATH"
source ~/.asdf/asdf.sh

# 環境変数をCodeBuildの環境変数ファイルに保存
echo "export PATH=\"$HOME/.asdf/bin:$HOME/.cargo/bin:\$PATH\"" >> /tmp/codebuild_env
echo "source ~/.asdf/asdf.sh" >> /tmp/codebuild_env

# Pythonプラグインの追加
echo "asdf Pythonプラグインを追加中..."
asdf plugin add python || true

# Node.jsプラグインの追加（CDK用）
echo "asdf Node.jsプラグインを追加中..."
asdf plugin add nodejs || true

# .tool-versionsファイルが存在する場合、指定されたバージョンをインストール
if [ -f ".tool-versions" ]; then
    echo ".tool-versionsからランタイムをインストール中..."
    asdf install
    asdf reshim
fi

# uvのインストール
echo "uvをインストール中..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
    echo "export PATH=\"$HOME/.cargo/bin:\$PATH\"" >> /tmp/codebuild_env
fi

echo "=== 共通インストール完了 ==="

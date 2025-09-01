#!/bin/bash
# 共通インストールスクリプト
# CodeBuildで使用する共通のパッケージとツールをインストールする

set -e

echo "=== 共通インストール開始 ==="

# システムパッケージの更新
echo "システムパッケージを更新中..."
apt-get update -y

# 必要なパッケージのインストール
echo "必要なパッケージをインストール中..."
apt-get install -y \
    curl \
    wget \
    unzip \
    jq \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release

# asdfのインストール
echo "asdfをインストール中..."
if [ ! -d "$HOME/.asdf" ]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
fi

# asdfの環境設定
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
export PATH="$HOME/.asdf/bin:$PATH"
source ~/.asdf/asdf.sh

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

# uvのインストール（Python パッケージマネージャー）
echo "uvをインストール中..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.cargo/bin:$PATH"

# AWS CLIの最新版をインストール（CodeBuildのデフォルトより新しいバージョンが必要な場合）
echo "AWS CLI v2をインストール中..."
if ! command -v aws &> /dev/null || [[ $(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1) -lt 2 ]]; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install --update
    rm -rf awscliv2.zip aws/
fi

# SAM CLIのインストール
echo "AWS SAM CLIをインストール中..."
if ! command -v sam &> /dev/null; then
    wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
    unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
    ./sam-installation/install
    rm -rf aws-sam-cli-linux-x86_64.zip sam-installation/
fi

echo "=== 共通インストール完了 ==="
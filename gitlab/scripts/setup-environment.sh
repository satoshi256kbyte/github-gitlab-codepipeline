#!/bin/bash
# GitLab CI/CD環境セットアップスクリプト

set -e

echo "=== GitLab CI/CD Environment Setup ==="

# 基本ツールのインストール
echo "Installing basic tools..."
apt-get update -qq
apt-get install -y -qq \
    git \
    curl \
    unzip \
    jq \
    zip \
    wget \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release

# asdfのインストール
echo "Installing asdf..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. ~/.asdf/asdf.sh' >> ~/.bashrc
export PATH="$HOME/.asdf/bin:$PATH"
. ~/.asdf/asdf.sh

# プラグインの追加
echo "Adding asdf plugins..."
asdf plugin add python
asdf plugin add nodejs

# バージョンのインストール
echo "Installing runtime versions..."
asdf install

# uvのインストール
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.cargo/bin:$PATH"

# AWS CLIのインストール
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

# バージョン確認
echo "=== Version Information ==="
python --version
node --version
npm --version
uv --version
aws --version

echo "=== Environment Setup Completed ==="
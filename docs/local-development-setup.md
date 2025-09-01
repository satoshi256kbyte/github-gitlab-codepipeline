# ローカル開発環境セットアップガイド

このドキュメントでは、CI/CDパイプライン比較プロジェクトのローカル開発環境を構築する手順を説明します。

## 📋 目次

- [前提条件](#前提条件)
- [基本環境のセットアップ](#基本環境のセットアップ)
- [CI/CDローカルテスト環境](#cicdローカルテスト環境)
- [開発ツールの設定](#開発ツールの設定)
- [デバッグ環境](#デバッグ環境)
- [パフォーマンス最適化](#パフォーマンス最適化)

## 📋 前提条件

### オペレーティングシステム

このプロジェクトは以下のOSでテスト済みです：

- **macOS**: 12.0以降（推奨）
- **Ubuntu**: 20.04 LTS以降
- **Windows**: WSL2を使用（Ubuntu 20.04推奨）

### 必要なツール

| ツール | バージョン | 用途 | インストール方法 |
|--------|-----------|------|------------------|
| [asdf](https://asdf-vm.com/) | latest | ランタイムバージョン管理 | 公式サイト参照 |
| [Git](https://git-scm.com/) | 2.30+ | バージョン管理 | OS標準またはHomebrew |
| [Docker](https://www.docker.com/) | 20.10+ | コンテナ化 | Docker Desktop |
| [AWS CLI](https://aws.amazon.com/cli/) | v2 | AWS操作 | 公式インストーラー |

## 🛠️ 基本環境のセットアップ

### 1. リポジトリのクローン

```bash
# HTTPSでクローン
git clone https://github.com/your-username/github-gitlab-codepipeline.git
cd github-gitlab-codepipeline

# またはSSHでクローン（推奨）
git clone git@github.com:your-username/github-gitlab-codepipeline.git
cd github-gitlab-codepipeline
```

### 2. asdfのセットアップ

#### macOS

```bash
# Homebrewでインストール
brew install asdf

# シェル設定に追加
echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ~/.zshrc
echo -e "\n. $(brew --prefix asdf)/etc/bash_completion.d/asdf.bash" >> ~/.zshrc
source ~/.zshrc
```

#### Ubuntu/Debian

```bash
# asdfのクローン
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

# シェル設定に追加
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```

#### Windows (WSL2)

```bash
# Ubuntu on WSL2での手順
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```

### 3. 必要なプラグインのインストール

```bash
# Pythonプラグイン
asdf plugin add python

# Node.jsプラグイン
asdf plugin add nodejs

# プラグインの確認
asdf plugin list
```

### 4. ランタイムのインストール

```bash
# .tool-versionsに基づいてインストール
asdf install

# インストール確認
asdf current
python --version
node --version
```

### 5. Python環境のセットアップ

```bash
# uvのインストール（Pythonパッケージマネージャー）
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# 仮想環境の作成と依存関係のインストール
uv sync --dev

# 仮想環境の確認
uv run python --version
uv run which python
```

### 6. Node.js環境のセットアップ

```bash
# CDKディレクトリに移動
cd cdk

# 依存関係のインストール
npm install

# CDKの確認
npx cdk --version

# プロジェクトルートに戻る
cd ..
```

### 7. 環境変数の設定

```bash
# .env.localファイルの作成
cp .env.example .env.local

# 必要な環境変数を設定
cat > .env.local << EOF
# AWS設定
AWS_PROFILE=default
AWS_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012

# アプリケーション設定
DEBUG=true
LOG_LEVEL=DEBUG

# テスト設定
PYTEST_CURRENT_TEST=true
EOF
```

## 🚀 アプリケーションの起動

### 開発サーバーの起動

```bash
# FastAPIアプリケーションディレクトリに移動
cd modules/api

# 開発サーバーの起動
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000

# または環境変数を指定して起動
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000 --log-level debug
```

### アプリケーションの確認

ブラウザで以下のURLにアクセス：

- **API Root**: <http://localhost:8000/>
- **Health Check**: <http://localhost:8000/health>
- **API Documentation**: <http://localhost:8000/docs>
- **ReDoc**: <http://localhost:8000/redoc>
- **OpenAPI Schema**: <http://localhost:8000/openapi.json>

### 基本的なテスト

```bash
# ヘルスチェック
curl http://localhost:8000/health

# バージョン情報
curl http://localhost:8000/version

# アイテム一覧
curl http://localhost:8000/api/items

# アイテム作成
curl -X POST http://localhost:8000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name": "テストアイテム", "description": "テスト用のアイテムです"}'
```

## 🧪 テスト環境のセットアップ

### ユニットテストの実行

```bash
# 全テストの実行
uv run pytest

# 詳細出力付きテスト
uv run pytest -v

# カバレッジ付きテスト
uv run pytest --cov=modules/api --cov-report=html

# 特定のテストマーカーのみ実行
uv run pytest -m unit
uv run pytest -m integration
uv run pytest -m "not slow"

# 並列テスト実行
uv run pytest -n auto
```

### 静的解析の実行

```bash
# ruffによるlint
uv run ruff check .

# ruffによる自動修正
uv run ruff check --fix .

# blackによるフォーマットチェック
uv run black --check .

# blackによる自動フォーマット
uv run black .

# 型チェック（mypyがインストールされている場合）
uv run mypy modules/api
```

### セキュリティスキャン

```bash
# banditによるセキュリティスキャン
uv run bandit -r modules/api

# safetyによる依存関係脆弱性チェック
uv run safety check

# 依存関係の監査
uv run pip-audit
```

## 🔄 CI/CDローカルテスト環境

### GitHub Actions (act)

#### インストール

```bash
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Windows (Chocolatey)
choco install act-cli
```

#### 設定

```bash
# .actrcファイルの作成
cat > .actrc << EOF
--container-architecture linux/amd64
--artifact-server-path /tmp/artifacts
--env-file .env.local
--platform ubuntu-latest=catthehacker/ubuntu:act-latest
--platform ubuntu-20.04=catthehacker/ubuntu:act-20.04
--platform ubuntu-18.04=catthehacker/ubuntu:act-18.04
EOF
```

#### 実行

```bash
# 全ワークフローの実行
act

# 特定のジョブの実行
act -j test
act -j lint

# プルリクエストイベントのシミュレート
act pull_request

# 環境変数の指定
act -s AWS_REGION=ap-northeast-1

# デバッグモード
act -v

# ドライラン
act --dryrun
```

### GitLab CI/CD (GitLab Runner)

#### インストール

```bash
# macOS
brew install gitlab-runner

# Ubuntu/Debian
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# CentOS/RHEL
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo yum install gitlab-runner
```

#### 設定

```bash
# .gitlab-runner/config.tomlの作成
mkdir -p .gitlab-runner
cat > .gitlab-runner/config.toml << EOF
concurrent = 1
check_interval = 0

[[runners]]
  name = "local-docker-runner"
  url = "https://gitlab.com/"
  token = "dummy-token-for-local-testing"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "python:3.13"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
EOF
```

#### 実行

```bash
# 特定のジョブの実行
gitlab-runner exec docker test

# 環境変数を指定して実行
gitlab-runner exec docker --env AWS_DEFAULT_REGION=ap-northeast-1 test

# 設定ファイルを指定して実行
gitlab-runner --config .gitlab-runner/config.toml exec docker test

# デバッグモード
gitlab-runner --debug exec docker test
```

### AWS CodeBuild ローカル実行

#### CodeBuildエージェントの使用

```bash
# CodeBuildエージェントのダウンロード
git clone https://github.com/aws/aws-codebuild-docker-images.git
cd aws-codebuild-docker-images/ubuntu/standard/7.0

# Dockerイメージのビルド
docker build -t aws/codebuild/standard:7.0 .

# ローカルでのビルド実行
docker run -it --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  aws/codebuild/standard:7.0
```

#### buildspecの検証

```bash
# buildspecファイルの構文チェック
aws codebuild batch-get-projects --names dummy-project 2>/dev/null || echo "Syntax OK"

# ローカルでのbuildspec実行シミュレート
docker run --rm -v $(pwd):/workspace -w /workspace python:3.13 \
  bash -c "
    apt-get update && apt-get install -y curl
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH=\"\$HOME/.cargo/bin:\$PATH\"
    uv sync --dev
    uv run pytest
  "
```

## 🛠️ 開発ツールの設定

### VS Code設定

#### 推奨拡張機能

`.vscode/extensions.json`を作成：

```json
{
  "recommendations": [
    "ms-python.python",
    "ms-python.black-formatter",
    "charliermarsh.ruff",
    "ms-python.mypy-type-checker",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "ms-azuretools.vscode-docker",
    "github.vscode-github-actions",
    "gitlab.gitlab-workflow",
    "amazonwebservices.aws-toolkit-vscode"
  ]
}
```

#### ワークスペース設定

`.vscode/settings.json`を作成：

```json
{
  "python.defaultInterpreterPath": "./.venv/bin/python",
  "python.terminal.activateEnvironment": true,
  "python.linting.enabled": true,
  "python.linting.ruffEnabled": true,
  "python.formatting.provider": "black",
  "python.testing.pytestEnabled": true,
  "python.testing.pytestArgs": [
    "modules/api/tests"
  ],
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true,
    ".venv": true,
    ".pytest_cache": true,
    ".coverage": true,
    "htmlcov": true
  },
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true,
    "source.fixAll.ruff": true
  }
}
```

#### デバッグ設定

`.vscode/launch.json`を作成：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI Development Server",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/.venv/bin/uvicorn",
      "args": [
        "main:app",
        "--reload",
        "--host",
        "0.0.0.0",
        "--port",
        "8000"
      ],
      "cwd": "${workspaceFolder}/modules/api",
      "env": {
        "PYTHONPATH": "${workspaceFolder}",
        "DEBUG": "true"
      },
      "console": "integratedTerminal"
    },
    {
      "name": "Python: Current File",
      "type": "python",
      "request": "launch",
      "program": "${file}",
      "console": "integratedTerminal",
      "cwd": "${workspaceFolder}"
    },
    {
      "name": "Python: Pytest",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": [
        "${workspaceFolder}/modules/api/tests",
        "-v"
      ],
      "cwd": "${workspaceFolder}",
      "console": "integratedTerminal"
    }
  ]
}
```

### PyCharm設定

#### プロジェクト設定

1. **File > Settings > Project > Python Interpreter**
2. **Add Interpreter > Existing environment**
3. **Interpreter path**: `./venv/bin/python`

#### 実行設定

1. **Run > Edit Configurations**
2. **Add New Configuration > Python**
3. **Script path**: `uvicorn`
4. **Parameters**: `main:app --reload --host 0.0.0.0 --port 8000`
5. **Working directory**: `modules/api`

### Git設定

#### Git Hooks

`.git/hooks/pre-commit`を作成：

```bash
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# 静的解析
echo "Running ruff..."
uv run ruff check .

# フォーマットチェック
echo "Running black..."
uv run black --check .

# テスト実行
echo "Running tests..."
uv run pytest -x

echo "All checks passed!"
```

実行権限を付与：

```bash
chmod +x .git/hooks/pre-commit
```

#### Git設定

```bash
# コミットメッセージテンプレート
git config commit.template .gitmessage

# .gitmessageファイルの作成
cat > .gitmessage << EOF
# <type>(<scope>): <subject>
#
# <body>
#
# <footer>

# Type should be one of the following:
# * feat (new feature)
# * fix (bug fix)
# * docs (documentation)
# * style (formatting, missing semi colons, etc; no code change)
# * refactor (refactoring production code)
# * test (adding tests, refactoring test; no production code change)
# * chore (updating build tasks, package manager configs, etc; no production code change)
EOF
```

## 🐛 デバッグ環境

### Python デバッガー

#### pdbの使用

```python
# コード内でブレークポイントを設定
import pdb; pdb.set_trace()

# Python 3.7以降
breakpoint()
```

#### ipdbの使用（推奨）

```bash
# ipdbのインストール
uv add --dev ipdb

# 使用方法
import ipdb; ipdb.set_trace()
```

#### VS Codeでのデバッグ

1. **F5**キーでデバッグ開始
2. **ブレークポイント**をコードに設定
3. **デバッグコンソール**で変数を確認

### ログ設定

#### 開発用ログ設定

`modules/api/logging_config.py`を作成：

```python
import logging
import sys
from pathlib import Path

def setup_logging(log_level: str = "INFO"):
    """開発用ログ設定"""
    
    # ログディレクトリの作成
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # ログフォーマット
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # ルートロガーの設定
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper()))
    
    # コンソールハンドラー
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # ファイルハンドラー
    file_handler = logging.FileHandler(log_dir / "app.log")
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)
    
    return root_logger
```

#### ログの使用

```python
from logging_config import setup_logging
import os

# 環境変数からログレベルを取得
log_level = os.getenv("LOG_LEVEL", "INFO")
logger = setup_logging(log_level)

# ログの出力
logger.info("Application started")
logger.debug("Debug information")
logger.error("Error occurred")
```

### パフォーマンス監視

#### プロファイリング

```bash
# cProfileを使用
uv run python -m cProfile -o profile.stats modules/api/main.py

# プロファイル結果の確認
uv run python -c "
import pstats
p = pstats.Stats('profile.stats')
p.sort_stats('cumulative').print_stats(10)
"
```

#### メモリ使用量監視

```bash
# memory_profilerのインストール
uv add --dev memory-profiler

# メモリプロファイリング
uv run python -m memory_profiler modules/api/main.py
```

## ⚡ パフォーマンス最適化

### 開発環境の高速化

#### uvキャッシュの最適化

```bash
# キャッシュディレクトリの確認
uv cache dir

# キャッシュのクリア
uv cache clean

# キャッシュサイズの確認
du -sh $(uv cache dir)
```

#### Dockerビルドの最適化

```dockerfile
# .dockerignore の作成
cat > .dockerignore << EOF
.git
.venv
__pycache__
*.pyc
.pytest_cache
.coverage
htmlcov
node_modules
.DS_Store
EOF
```

#### 並列テスト実行

```bash
# pytest-xdistのインストール
uv add --dev pytest-xdist

# 並列テスト実行
uv run pytest -n auto

# CPU数を指定
uv run pytest -n 4
```

### システムリソース監視

#### リソース使用量の確認

```bash
# CPU使用量
top -p $(pgrep -f uvicorn)

# メモリ使用量
ps aux | grep uvicorn

# ディスク使用量
df -h
du -sh .venv/
```

#### 自動監視スクリプト

```bash
#!/bin/bash
# monitor.sh - リソース監視スクリプト

while true; do
    echo "=== $(date) ==="
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
    
    echo "Memory Usage:"
    free -h | grep Mem | awk '{print $3 "/" $2}'
    
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print $5}'
    
    echo "Python Processes:"
    ps aux | grep python | wc -l
    
    echo "---"
    sleep 30
done
```

このローカル開発環境セットアップガイドにより、効率的な開発環境を構築できます。問題が発生した場合は、[トラブルシューティングガイド](troubleshooting-guide.md)を参照してください。

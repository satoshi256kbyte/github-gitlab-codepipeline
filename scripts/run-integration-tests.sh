#!/bin/bash
"""
統合テスト実行スクリプト

CI/CDツール間の独立性とCloudWatchログ分離を確認する
統合テストを実行する。
"""

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== CI/CD統合テスト実行 ==="
echo "プロジェクトルート: $PROJECT_ROOT"
echo ""

# Python環境の確認
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3が見つかりません"
    exit 1
fi

# 必要なPythonパッケージの確認
echo "📦 依存関係の確認..."
cd "$PROJECT_ROOT"

if [ -f "pyproject.toml" ]; then
    echo "✓ pyproject.tomlが見つかりました"
    
    # uvが利用可能な場合は使用
    if command -v uv &> /dev/null; then
        echo "📦 uvで依存関係をインストール中..."
        uv sync
    else
        echo "📦 pipで依存関係をインストール中..."
        pip install -e .
        pip install pytest pytest-asyncio httpx boto3
    fi
else
    echo "⚠️ pyproject.tomlが見つかりません。手動で依存関係をインストールします..."
    pip install pytest pytest-asyncio httpx boto3 pyyaml
fi

echo ""

# AWS認証情報の確認
echo "🔐 AWS認証情報の確認..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✓ AWS認証情報が設定されています"
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    echo "  アカウント: $AWS_ACCOUNT"
    echo "  リージョン: $AWS_REGION"
else
    echo "⚠️ AWS認証情報が設定されていません"
    echo "  一部のテストはスキップされます"
fi

echo ""

# テスト実行
echo "🧪 統合テストを実行中..."
echo ""

# CI/CDツール独立性テスト
echo "--- CI/CDツール独立性テスト ---"
python -m pytest modules/api/tests/test_cicd_tool_isolation.py -v --tb=short

echo ""

# CloudWatchログ分離テスト
echo "--- CloudWatchログ分離テスト ---"
python -m pytest modules/api/tests/test_cloudwatch_log_separation.py -v --tb=short

echo ""

# CI/CD設定ファイル比較分析
echo "--- CI/CD設定ファイル比較分析 ---"
python scripts/analyze-cicd-configs.py --format both --output-dir docs

echo ""

# テスト結果サマリー
echo "=== テスト結果サマリー ==="

# pytest結果の確認
if [ $? -eq 0 ]; then
    echo "✅ 全ての統合テストが正常に完了しました"
else
    echo "❌ 一部のテストが失敗しました"
    echo "詳細は上記のテスト出力を確認してください"
fi

echo ""
echo "📊 分析レポートが生成されました:"
echo "  - docs/cicd-config-comparison.md"
echo "  - docs/cicd-config-analysis.json"

echo ""
echo "🎯 次のステップ:"
echo "  1. AWS CDKでインフラをデプロイ"
echo "  2. 各CI/CDパイプラインを実行"
echo "  3. 再度統合テストを実行して完全な検証を行う"

echo ""
echo "=== 統合テスト完了 ==="
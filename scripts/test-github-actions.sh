#!/bin/bash

# GitHub Actions ローカルテスト実行スクリプト
# actツールを使用してGitHub Actionsワークフローをローカルで実行

set -e

# 色付きログ出力用の関数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# actツールのインストール確認
check_act_installation() {
    if ! command -v act &> /dev/null; then
        log_error "actツールがインストールされていません"
        log_info "インストール方法:"
        log_info "  macOS: brew install act"
        log_info "  Linux: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
        exit 1
    fi
    log_info "actツールが見つかりました: $(act --version)"
}

# Dockerの動作確認
check_docker() {
    if ! docker info &> /dev/null; then
        log_error "Dockerが起動していません"
        log_info "Dockerを起動してから再実行してください"
        exit 1
    fi
    log_info "Dockerが正常に動作しています"
}

# 環境変数ファイルの確認
check_env_file() {
    if [ ! -f ".env.local" ]; then
        log_warn ".env.localファイルが見つかりません"
        log_info "サンプルファイルをコピーして設定してください"
        return 1
    fi
    log_info ".env.localファイルが見つかりました"
}

# 使用方法の表示
show_usage() {
    echo "使用方法: $0 [オプション] [ワークフロー名]"
    echo ""
    echo "オプション:"
    echo "  -l, --list          利用可能なワークフローを一覧表示"
    echo "  -j, --job JOB_NAME  特定のジョブのみを実行"
    echo "  -e, --event EVENT   イベントタイプを指定 (push, pull_request等)"
    echo "  -n, --dry-run       ドライラン（実際には実行しない）"
    echo "  -v, --verbose       詳細ログを表示"
    echo "  -h, --help          このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0                          # 全ワークフローを実行"
    echo "  $0 ci.yml                   # ci.ymlワークフローのみ実行"
    echo "  $0 -j lint                  # lintジョブのみ実行"
    echo "  $0 -e pull_request          # pull_requestイベントで実行"
    echo "  $0 -n                       # ドライラン"
}

# ワークフロー一覧の表示
list_workflows() {
    log_info "利用可能なワークフロー:"
    if [ -d ".github/workflows" ]; then
        find .github/workflows -name "*.yml" -o -name "*.yaml" | sed 's|.github/workflows/||' | sort
    else
        log_warn ".github/workflowsディレクトリが見つかりません"
    fi
}

# メイン実行関数
run_act() {
    local workflow_file="$1"
    local job_name="$2"
    local event_type="${3:-push}"
    local dry_run="$4"
    local verbose="$5"

    local act_cmd="act"
    
    # イベントタイプの指定
    act_cmd="$act_cmd $event_type"
    
    # ワークフローファイルの指定
    if [ -n "$workflow_file" ]; then
        act_cmd="$act_cmd -W .github/workflows/$workflow_file"
    fi
    
    # ジョブ名の指定
    if [ -n "$job_name" ]; then
        act_cmd="$act_cmd -j $job_name"
    fi
    
    # ドライランの指定
    if [ "$dry_run" = "true" ]; then
        act_cmd="$act_cmd --dry-run"
    fi
    
    # 詳細ログの指定
    if [ "$verbose" = "true" ]; then
        act_cmd="$act_cmd --verbose"
    fi

    log_info "実行コマンド: $act_cmd"
    
    if [ "$dry_run" = "true" ]; then
        log_info "ドライラン実行中..."
    else
        log_info "GitHub Actionsワークフローをローカル実行中..."
    fi
    
    eval $act_cmd
}

# メイン処理
main() {
    local workflow_file=""
    local job_name=""
    local event_type="push"
    local dry_run="false"
    local verbose="false"
    local list_only="false"

    # 引数の解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--list)
                list_only="true"
                shift
                ;;
            -j|--job)
                job_name="$2"
                shift 2
                ;;
            -e|--event)
                event_type="$2"
                shift 2
                ;;
            -n|--dry-run)
                dry_run="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "不明なオプション: $1"
                show_usage
                exit 1
                ;;
            *)
                workflow_file="$1"
                shift
                ;;
        esac
    done

    # 事前チェック
    check_act_installation
    check_docker
    check_env_file

    # ワークフロー一覧表示のみの場合
    if [ "$list_only" = "true" ]; then
        list_workflows
        exit 0
    fi

    # actの実行
    run_act "$workflow_file" "$job_name" "$event_type" "$dry_run" "$verbose"
    
    log_info "GitHub Actionsローカルテストが完了しました"
}

# スクリプト実行
main "$@"
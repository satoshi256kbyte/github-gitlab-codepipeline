#!/bin/bash

# GitLab CI/CD ローカルテスト実行スクリプト
# GitLab Runnerを使用してGitLab CI/CDパイプラインをローカルで実行

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

# GitLab Runnerのインストール確認
check_gitlab_runner_installation() {
    if ! command -v gitlab-runner &> /dev/null; then
        log_warn "GitLab Runnerがローカルにインストールされていません"
        log_info "Dockerを使用してGitLab Runnerを実行します"
        return 1
    fi
    log_info "GitLab Runnerが見つかりました: $(gitlab-runner --version)"
    return 0
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

# GitLab CI設定ファイルの確認
check_gitlab_ci_file() {
    if [ ! -f ".gitlab-ci.yml" ]; then
        log_error ".gitlab-ci.ymlファイルが見つかりません"
        log_info "GitLab CI/CD設定ファイルを作成してください"
        exit 1
    fi
    log_info ".gitlab-ci.ymlファイルが見つかりました"
}

# 使用方法の表示
show_usage() {
    echo "使用方法: $0 [オプション] [ジョブ名]"
    echo ""
    echo "オプション:"
    echo "  -l, --list          利用可能なジョブを一覧表示"
    echo "  -s, --stage STAGE   特定のステージのジョブのみを実行"
    echo "  -e, --executor TYPE 実行環境を指定 (docker, shell, kubernetes)"
    echo "  -d, --docker        Docker Composeを使用して実行"
    echo "  -v, --validate      .gitlab-ci.ymlの構文チェックのみ"
    echo "  -c, --cleanup       実行後にコンテナを削除"
    echo "  --dry-run           ドライラン（実際には実行しない）"
    echo "  --verbose           詳細ログを表示"
    echo "  -h, --help          このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0                          # 全ジョブを実行"
    echo "  $0 lint                     # lintジョブのみ実行"
    echo "  $0 -s test                  # testステージのジョブを実行"
    echo "  $0 -d                       # Docker Composeで実行"
    echo "  $0 -v                       # 構文チェックのみ"
    echo "  $0 --dry-run                # ドライラン"
}

# ジョブ一覧の表示
list_jobs() {
    log_info "GitLab CI/CDジョブの解析中..."
    
    if command -v yq &> /dev/null; then
        log_info "利用可能なジョブ:"
        yq eval 'keys | .[]' .gitlab-ci.yml | grep -v '^stages$' | grep -v '^variables$' | grep -v '^before_script$' | grep -v '^after_script$' | sort
    elif command -v python3 &> /dev/null; then
        log_info "利用可能なジョブ（Python解析）:"
        python3 -c "
import yaml
with open('.gitlab-ci.yml', 'r') as f:
    ci_config = yaml.safe_load(f)
jobs = [k for k in ci_config.keys() if not k.startswith('.') and k not in ['stages', 'variables', 'before_script', 'after_script', 'image', 'services']]
for job in sorted(jobs):
    print(job)
"
    else
        log_warn "yqまたはPython3が必要です"
        log_info "手動で.gitlab-ci.ymlを確認してください"
    fi
}

# GitLab CI/CD構文チェック
validate_gitlab_ci() {
    log_info "GitLab CI/CD設定ファイルの構文チェック中..."
    
    if command -v gitlab-runner &> /dev/null; then
        if gitlab-runner exec docker --dry-run lint 2>/dev/null; then
            log_info "構文チェック: OK"
        else
            log_warn "gitlab-runnerでの構文チェックに失敗しました"
        fi
    fi
    
    # YAMLの基本構文チェック
    if command -v python3 &> /dev/null; then
        python3 -c "
import yaml
try:
    with open('.gitlab-ci.yml', 'r') as f:
        yaml.safe_load(f)
    print('YAML構文: OK')
except yaml.YAMLError as e:
    print(f'YAML構文エラー: {e}')
    exit(1)
"
    fi
}

# Docker Composeでの実行
run_with_docker_compose() {
    local job_name="$1"
    
    log_info "Docker Composeを使用してGitLab CI/CDを実行中..."
    
    cd .gitlab-runner
    
    # Docker Composeサービスの起動
    docker-compose up -d gitlab-runner
    
    # GitLab Runnerの準備完了を待機
    log_info "GitLab Runnerの準備完了を待機中..."
    sleep 10
    
    # ジョブの実行
    if [ -n "$job_name" ]; then
        log_info "ジョブ '$job_name' を実行中..."
        docker-compose exec gitlab-runner gitlab-runner exec docker "$job_name"
    else
        log_info "全ジョブを実行中..."
        # 利用可能なジョブを順次実行
        for job in $(cd .. && python3 -c "
import yaml
with open('.gitlab-ci.yml', 'r') as f:
    ci_config = yaml.safe_load(f)
jobs = [k for k in ci_config.keys() if not k.startswith('.') and k not in ['stages', 'variables', 'before_script', 'after_script', 'image', 'services']]
print(' '.join(sorted(jobs)))
" 2>/dev/null || echo "lint test"); do
            log_info "ジョブ '$job' を実行中..."
            docker-compose exec gitlab-runner gitlab-runner exec docker "$job" || log_warn "ジョブ '$job' が失敗しました"
        done
    fi
    
    cd ..
}

# ローカルGitLab Runnerでの実行
run_with_local_runner() {
    local job_name="$1"
    local executor="${2:-docker}"
    
    log_info "ローカルGitLab Runnerで実行中..."
    
    if [ -n "$job_name" ]; then
        log_info "ジョブ '$job_name' を実行中..."
        gitlab-runner exec "$executor" "$job_name"
    else
        log_warn "ローカルRunnerでは特定のジョブ名が必要です"
        log_info "利用可能なジョブを表示します:"
        list_jobs
    fi
}

# クリーンアップ
cleanup() {
    log_info "クリーンアップ中..."
    
    # Docker Composeサービスの停止
    if [ -f ".gitlab-runner/docker-compose.yml" ]; then
        cd .gitlab-runner
        docker-compose down -v
        cd ..
    fi
    
    # 不要なDockerコンテナの削除
    docker container prune -f
    docker image prune -f
    
    log_info "クリーンアップが完了しました"
}

# メイン処理
main() {
    local job_name=""
    local stage_name=""
    local executor="docker"
    local use_docker_compose="false"
    local validate_only="false"
    local cleanup_after="false"
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
            -s|--stage)
                stage_name="$2"
                shift 2
                ;;
            -e|--executor)
                executor="$2"
                shift 2
                ;;
            -d|--docker)
                use_docker_compose="true"
                shift
                ;;
            -v|--validate)
                validate_only="true"
                shift
                ;;
            -c|--cleanup)
                cleanup_after="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --verbose)
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
                job_name="$1"
                shift
                ;;
        esac
    done

    # 事前チェック
    check_docker
    check_gitlab_ci_file

    # ジョブ一覧表示のみの場合
    if [ "$list_only" = "true" ]; then
        list_jobs
        exit 0
    fi

    # 構文チェックのみの場合
    if [ "$validate_only" = "true" ]; then
        validate_gitlab_ci
        exit 0
    fi

    # ドライランの場合
    if [ "$dry_run" = "true" ]; then
        log_info "ドライラン: 以下のコマンドが実行されます"
        if [ "$use_docker_compose" = "true" ]; then
            echo "docker-compose -f .gitlab-runner/docker-compose.yml up -d"
            echo "docker-compose -f .gitlab-runner/docker-compose.yml exec gitlab-runner gitlab-runner exec docker $job_name"
        else
            echo "gitlab-runner exec $executor $job_name"
        fi
        exit 0
    fi

    # GitLab CI/CDの実行
    if [ "$use_docker_compose" = "true" ]; then
        run_with_docker_compose "$job_name"
    else
        if check_gitlab_runner_installation; then
            run_with_local_runner "$job_name" "$executor"
        else
            log_info "Docker Composeを使用して実行します"
            run_with_docker_compose "$job_name"
        fi
    fi

    # クリーンアップ
    if [ "$cleanup_after" = "true" ]; then
        cleanup
    fi
    
    log_info "GitLab CI/CDローカルテストが完了しました"
}

# 終了時のクリーンアップ設定
trap cleanup EXIT

# スクリプト実行
main "$@"
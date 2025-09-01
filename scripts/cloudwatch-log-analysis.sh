#!/bin/bash

# CloudWatch ログ分析スクリプト
# CI/CDツール別のログを収集・比較するためのユーティリティ

set -e

# 設定
ENVIRONMENT="${ENVIRONMENT:-local}"
SERVICE_NAME="${SERVICE_NAME:-cicd-comparison}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
CICD_TOOLS=("github" "gitlab" "codepipeline")

# 色付きログ出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 使用方法を表示
show_usage() {
    cat << EOF
CloudWatch ログ分析スクリプト

使用方法:
  $0 [コマンド] [オプション]

コマンド:
  list-log-groups     CI/CDツール別のログ グループ一覧を表示
  get-recent-logs     最近のログを取得（デフォルト: 1時間）
  get-error-logs      エラーログのみを取得
  compare-performance パフォーマンス比較レポートを生成
  export-logs         ログをファイルにエクスポート
  tail-logs          リアルタイムでログを監視

オプション:
  --cicd-tool TOOL    特定のCI/CDツールのみ対象（github, gitlab, codepipeline）
  --log-type TYPE     ログタイプを指定（lambda, ecs-app, ecs-system, ec2-app, ec2-system, ec2-codedeploy, apigateway）
  --start-time TIME   開始時刻（ISO8601形式またはUnixタイムスタンプ）
  --end-time TIME     終了時刻（ISO8601形式またはUnixタイムスタンプ）
  --output-dir DIR    出力ディレクトリ（デフォルト: ./logs）
  --format FORMAT     出力形式（json, text, csv）
  --help             このヘルプを表示

例:
  $0 list-log-groups
  $0 get-recent-logs --cicd-tool github --log-type lambda
  $0 get-error-logs --start-time "2024-01-01T00:00:00Z"
  $0 compare-performance --output-dir ./reports
  $0 tail-logs --cicd-tool gitlab --log-type ecs-app

EOF
}

# ログ グループ名を生成
generate_log_group_name() {
    local cicd_tool="$1"
    local log_type="$2"
    local resource_prefix="${cicd_tool}-${ENVIRONMENT}"
    
    case "$log_type" in
        "lambda")
            echo "/aws/lambda/${resource_prefix}-lambda-api"
            ;;
        "ecs-app")
            echo "/ecs/${resource_prefix}-ecs-application"
            ;;
        "ecs-system")
            echo "/ecs/${resource_prefix}-ecs-system"
            ;;
        "ec2-app")
            echo "/ec2/${resource_prefix}-ec2-application"
            ;;
        "ec2-system")
            echo "/ec2/${resource_prefix}-ec2-system"
            ;;
        "ec2-codedeploy")
            echo "/ec2/${resource_prefix}-ec2-codedeploy"
            ;;
        "apigateway")
            echo "/aws/apigateway/${resource_prefix}-apigw-access"
            ;;
        *)
            log_error "Unknown log type: $log_type"
            return 1
            ;;
    esac
}

# ログ グループ一覧を表示
list_log_groups() {
    local target_cicd_tool="$1"
    local log_types=("lambda" "ecs-app" "ecs-system" "ec2-app" "ec2-system" "ec2-codedeploy" "apigateway")
    
    log_info "CI/CDツール別ログ グループ一覧"
    echo "=================================="
    
    for cicd_tool in "${CICD_TOOLS[@]}"; do
        if [[ -n "$target_cicd_tool" && "$cicd_tool" != "$target_cicd_tool" ]]; then
            continue
        fi
        
        echo ""
        log_info "CI/CDツール: $cicd_tool"
        echo "----------------------------"
        
        for log_type in "${log_types[@]}"; do
            local log_group_name
            log_group_name=$(generate_log_group_name "$cicd_tool" "$log_type")
            
            # ログ グループの存在確認
            if aws logs describe-log-groups \
                --log-group-name-prefix "$log_group_name" \
                --region "$AWS_REGION" \
                --query "logGroups[?logGroupName=='$log_group_name']" \
                --output text > /dev/null 2>&1; then
                echo "  ✓ $log_type: $log_group_name"
            else
                echo "  ✗ $log_type: $log_group_name (存在しません)"
            fi
        done
    done
}

# 最近のログを取得
get_recent_logs() {
    local cicd_tool="$1"
    local log_type="$2"
    local start_time="$3"
    local end_time="$4"
    local output_format="${5:-text}"
    
    # デフォルトで1時間前から現在まで
    if [[ -z "$start_time" ]]; then
        start_time=$(date -d '1 hour ago' -u +%s)000
    fi
    if [[ -z "$end_time" ]]; then
        end_time=$(date -u +%s)000
    fi
    
    # ISO8601形式の場合はUnixタイムスタンプに変換
    if [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        start_time=$(date -d "$start_time" -u +%s)000
    fi
    if [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        end_time=$(date -d "$end_time" -u +%s)000
    fi
    
    local tools_to_process=()
    if [[ -n "$cicd_tool" ]]; then
        tools_to_process=("$cicd_tool")
    else
        tools_to_process=("${CICD_TOOLS[@]}")
    fi
    
    local log_types_to_process=()
    if [[ -n "$log_type" ]]; then
        log_types_to_process=("$log_type")
    else
        log_types_to_process=("lambda" "ecs-app" "ec2-app")
    fi
    
    for tool in "${tools_to_process[@]}"; do
        for type in "${log_types_to_process[@]}"; do
            local log_group_name
            log_group_name=$(generate_log_group_name "$tool" "$type")
            
            log_info "ログ取得中: $tool - $type"
            log_debug "ログ グループ: $log_group_name"
            log_debug "期間: $(date -d @$((start_time/1000)) -u) - $(date -d @$((end_time/1000)) -u)"
            
            # ログ イベントを取得
            local events
            events=$(aws logs filter-log-events \
                --log-group-name "$log_group_name" \
                --start-time "$start_time" \
                --end-time "$end_time" \
                --region "$AWS_REGION" \
                --output json 2>/dev/null || echo '{"events":[]}')
            
            local event_count
            event_count=$(echo "$events" | jq '.events | length')
            
            if [[ "$event_count" -gt 0 ]]; then
                echo ""
                echo "=== $tool - $type ($event_count イベント) ==="
                
                case "$output_format" in
                    "json")
                        echo "$events" | jq '.events[]'
                        ;;
                    "csv")
                        echo "timestamp,message,logStream"
                        echo "$events" | jq -r '.events[] | [.timestamp, .message, .logStream] | @csv'
                        ;;
                    *)
                        echo "$events" | jq -r '.events[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")) [\(.logStream)] \(.message)"'
                        ;;
                esac
            else
                log_warn "ログが見つかりません: $tool - $type"
            fi
        done
    done
}

# エラーログのみを取得
get_error_logs() {
    local cicd_tool="$1"
    local start_time="$2"
    local end_time="$3"
    
    log_info "エラーログを検索中..."
    
    # デフォルトで24時間前から現在まで
    if [[ -z "$start_time" ]]; then
        start_time=$(date -d '24 hours ago' -u +%s)000
    fi
    if [[ -z "$end_time" ]]; then
        end_time=$(date -u +%s)000
    fi
    
    local tools_to_process=()
    if [[ -n "$cicd_tool" ]]; then
        tools_to_process=("$cicd_tool")
    else
        tools_to_process=("${CICD_TOOLS[@]}")
    fi
    
    for tool in "${tools_to_process[@]}"; do
        for log_type in "lambda" "ecs-app" "ec2-app"; do
            local log_group_name
            log_group_name=$(generate_log_group_name "$tool" "$log_type")
            
            log_debug "エラーログ検索中: $tool - $log_type"
            
            # エラーパターンでフィルタリング
            local events
            events=$(aws logs filter-log-events \
                --log-group-name "$log_group_name" \
                --start-time "$start_time" \
                --end-time "$end_time" \
                --filter-pattern "ERROR Exception error" \
                --region "$AWS_REGION" \
                --output json 2>/dev/null || echo '{"events":[]}')
            
            local error_count
            error_count=$(echo "$events" | jq '.events | length')
            
            if [[ "$error_count" -gt 0 ]]; then
                echo ""
                echo "=== エラーログ: $tool - $log_type ($error_count 件) ==="
                echo "$events" | jq -r '.events[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")) [\(.logStream)] \(.message)"'
            fi
        done
    done
}

# パフォーマンス比較レポートを生成
compare_performance() {
    local output_dir="$1"
    local start_time="$2"
    local end_time="$3"
    
    mkdir -p "$output_dir"
    
    # デフォルトで24時間前から現在まで
    if [[ -z "$start_time" ]]; then
        start_time=$(date -d '24 hours ago' -u +%s)000
    fi
    if [[ -z "$end_time" ]]; then
        end_time=$(date -u +%s)000
    fi
    
    local report_file="$output_dir/performance-comparison-$(date +%Y%m%d-%H%M%S).json"
    
    log_info "パフォーマンス比較レポートを生成中..."
    log_debug "出力ファイル: $report_file"
    
    echo "{" > "$report_file"
    echo "  \"reportGeneratedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "  \"period\": {" >> "$report_file"
    echo "    \"startTime\": \"$(date -d @$((start_time/1000)) -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "    \"endTime\": \"$(date -d @$((end_time/1000)) -u +%Y-%m-%dT%H:%M:%SZ)\"" >> "$report_file"
    echo "  }," >> "$report_file"
    echo "  \"cicdTools\": {" >> "$report_file"
    
    local first_tool=true
    for tool in "${CICD_TOOLS[@]}"; do
        if [[ "$first_tool" == false ]]; then
            echo "    ," >> "$report_file"
        fi
        first_tool=false
        
        echo "    \"$tool\": {" >> "$report_file"
        
        # 各デプロイ先のメトリクスを収集
        local first_type=true
        for log_type in "lambda" "ecs-app" "ec2-app"; do
            if [[ "$first_type" == false ]]; then
                echo "      ," >> "$report_file"
            fi
            first_type=false
            
            local log_group_name
            log_group_name=$(generate_log_group_name "$tool" "$log_type")
            
            # ログ統計を取得
            local events
            events=$(aws logs filter-log-events \
                --log-group-name "$log_group_name" \
                --start-time "$start_time" \
                --end-time "$end_time" \
                --region "$AWS_REGION" \
                --output json 2>/dev/null || echo '{"events":[]}')
            
            local total_events
            total_events=$(echo "$events" | jq '.events | length')
            
            local error_events
            error_events=$(echo "$events" | jq '[.events[] | select(.message | test("ERROR|Exception|error"))] | length')
            
            echo "      \"$log_type\": {" >> "$report_file"
            echo "        \"totalEvents\": $total_events," >> "$report_file"
            echo "        \"errorEvents\": $error_events," >> "$report_file"
            echo "        \"errorRate\": $(echo "scale=4; $error_events / ($total_events + 0.0001)" | bc -l)" >> "$report_file"
            echo "      }" >> "$report_file"
        done
        
        echo "    }" >> "$report_file"
    done
    
    echo "  }" >> "$report_file"
    echo "}" >> "$report_file"
    
    log_info "レポートが生成されました: $report_file"
    
    # サマリーを表示
    echo ""
    log_info "パフォーマンス比較サマリー"
    echo "=========================="
    jq -r '
        .cicdTools | to_entries[] | 
        "\(.key):" + 
        ((.value | to_entries[] | 
        "  \(.key): \(.value.totalEvents) events, \(.value.errorEvents) errors (\(.value.errorRate * 100 | floor)%)") | 
        join("\n"))
    ' "$report_file"
}

# ログをファイルにエクスポート
export_logs() {
    local cicd_tool="$1"
    local log_type="$2"
    local output_dir="$3"
    local start_time="$4"
    local end_time="$5"
    local format="${6:-json}"
    
    mkdir -p "$output_dir"
    
    # デフォルトで24時間前から現在まで
    if [[ -z "$start_time" ]]; then
        start_time=$(date -d '24 hours ago' -u +%s)000
    fi
    if [[ -z "$end_time" ]]; then
        end_time=$(date -u +%s)000
    fi
    
    local tools_to_process=()
    if [[ -n "$cicd_tool" ]]; then
        tools_to_process=("$cicd_tool")
    else
        tools_to_process=("${CICD_TOOLS[@]}")
    fi
    
    local log_types_to_process=()
    if [[ -n "$log_type" ]]; then
        log_types_to_process=("$log_type")
    else
        log_types_to_process=("lambda" "ecs-app" "ecs-system" "ec2-app" "ec2-system" "ec2-codedeploy" "apigateway")
    fi
    
    for tool in "${tools_to_process[@]}"; do
        for type in "${log_types_to_process[@]}"; do
            local log_group_name
            log_group_name=$(generate_log_group_name "$tool" "$type")
            
            local output_file="$output_dir/${tool}-${type}-$(date +%Y%m%d-%H%M%S).$format"
            
            log_info "ログをエクスポート中: $tool - $type -> $output_file"
            
            # ログ イベントを取得してファイルに保存
            aws logs filter-log-events \
                --log-group-name "$log_group_name" \
                --start-time "$start_time" \
                --end-time "$end_time" \
                --region "$AWS_REGION" \
                --output json > "$output_file.tmp" 2>/dev/null || echo '{"events":[]}' > "$output_file.tmp"
            
            case "$format" in
                "json")
                    mv "$output_file.tmp" "$output_file"
                    ;;
                "csv")
                    echo "timestamp,message,logStream" > "$output_file"
                    jq -r '.events[] | [.timestamp, .message, .logStream] | @csv' "$output_file.tmp" >> "$output_file"
                    rm "$output_file.tmp"
                    ;;
                "text")
                    jq -r '.events[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")) [\(.logStream)] \(.message)"' "$output_file.tmp" > "$output_file"
                    rm "$output_file.tmp"
                    ;;
            esac
            
            local event_count
            event_count=$(jq '.events | length' "$output_file.tmp" 2>/dev/null || echo "0")
            log_info "エクスポート完了: $event_count イベント"
        done
    done
}

# リアルタイムログ監視
tail_logs() {
    local cicd_tool="$1"
    local log_type="$2"
    
    if [[ -z "$cicd_tool" || -z "$log_type" ]]; then
        log_error "tail-logsコマンドには --cicd-tool と --log-type の指定が必要です"
        return 1
    fi
    
    local log_group_name
    log_group_name=$(generate_log_group_name "$cicd_tool" "$log_type")
    
    log_info "リアルタイムログ監視を開始: $cicd_tool - $log_type"
    log_debug "ログ グループ: $log_group_name"
    log_info "終了するには Ctrl+C を押してください"
    echo ""
    
    # AWS CLI でログをtail
    aws logs tail "$log_group_name" --follow --region "$AWS_REGION"
}

# メイン処理
main() {
    local command=""
    local cicd_tool=""
    local log_type=""
    local start_time=""
    local end_time=""
    local output_dir="./logs"
    local format="text"
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            list-log-groups|get-recent-logs|get-error-logs|compare-performance|export-logs|tail-logs)
                command="$1"
                shift
                ;;
            --cicd-tool)
                cicd_tool="$2"
                shift 2
                ;;
            --log-type)
                log_type="$2"
                shift 2
                ;;
            --start-time)
                start_time="$2"
                shift 2
                ;;
            --end-time)
                end_time="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # コマンドが指定されていない場合
    if [[ -z "$command" ]]; then
        log_error "コマンドを指定してください"
        show_usage
        exit 1
    fi
    
    # AWS CLIの確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLIがインストールされていません"
        exit 1
    fi
    
    # jqの確認
    if ! command -v jq &> /dev/null; then
        log_error "jqがインストールされていません"
        exit 1
    fi
    
    # コマンド実行
    case "$command" in
        "list-log-groups")
            list_log_groups "$cicd_tool"
            ;;
        "get-recent-logs")
            get_recent_logs "$cicd_tool" "$log_type" "$start_time" "$end_time" "$format"
            ;;
        "get-error-logs")
            get_error_logs "$cicd_tool" "$start_time" "$end_time"
            ;;
        "compare-performance")
            compare_performance "$output_dir" "$start_time" "$end_time"
            ;;
        "export-logs")
            export_logs "$cicd_tool" "$log_type" "$output_dir" "$start_time" "$end_time" "$format"
            ;;
        "tail-logs")
            tail_logs "$cicd_tool" "$log_type"
            ;;
        *)
            log_error "Unknown command: $command"
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"
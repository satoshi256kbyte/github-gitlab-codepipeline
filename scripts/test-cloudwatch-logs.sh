#!/bin/bash

# CloudWatch ログ設定テストスクリプト
# CI/CDツール別のログ グループが正しく作成されているかを確認

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

# ログ グループの存在確認
check_log_group_exists() {
    local log_group_name="$1"
    
    if aws logs describe-log-groups \
        --log-group-name-prefix "$log_group_name" \
        --region "$AWS_REGION" \
        --query "logGroups[?logGroupName=='$log_group_name']" \
        --output text > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ログ グループの詳細情報を取得
get_log_group_info() {
    local log_group_name="$1"
    
    aws logs describe-log-groups \
        --log-group-name-prefix "$log_group_name" \
        --region "$AWS_REGION" \
        --query "logGroups[?logGroupName=='$log_group_name'].[retentionInDays,storedBytes,creationTime]" \
        --output text 2>/dev/null || echo "N/A N/A N/A"
}

# テストログイベントを送信
send_test_log_event() {
    local log_group_name="$1"
    local log_stream_name="test-stream-$(date +%s)"
    local message="Test log event from CloudWatch log test script at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # ログストリームを作成
    aws logs create-log-stream \
        --log-group-name "$log_group_name" \
        --log-stream-name "$log_stream_name" \
        --region "$AWS_REGION" > /dev/null 2>&1 || true
    
    # ログイベントを送信
    aws logs put-log-events \
        --log-group-name "$log_group_name" \
        --log-stream-name "$log_stream_name" \
        --log-events timestamp=$(date +%s)000,message="$message" \
        --region "$AWS_REGION" > /dev/null 2>&1
    
    return $?
}

# メイン処理
main() {
    local test_mode="$1"
    
    log_info "CloudWatch ログ設定テストを開始します"
    log_debug "環境: $ENVIRONMENT"
    log_debug "リージョン: $AWS_REGION"
    log_debug "CI/CDツール: ${CICD_TOOLS[*]}"
    echo ""
    
    # AWS CLIの確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLIがインストールされていません"
        exit 1
    fi
    
    local total_groups=0
    local existing_groups=0
    local failed_groups=0
    
    # 各CI/CDツールのログ グループをチェック
    for cicd_tool in "${CICD_TOOLS[@]}"; do
        log_info "CI/CDツール: $cicd_tool"
        echo "=================================="
        
        local log_types=("lambda" "ecs-app" "ecs-system" "ec2-app" "ec2-system" "ec2-codedeploy" "apigateway")
        
        for log_type in "${log_types[@]}"; do
            local log_group_name
            log_group_name=$(generate_log_group_name "$cicd_tool" "$log_type")
            total_groups=$((total_groups + 1))
            
            printf "  %-15s: %-50s " "$log_type" "$log_group_name"
            
            if check_log_group_exists "$log_group_name"; then
                echo -e "${GREEN}✓ 存在${NC}"
                existing_groups=$((existing_groups + 1))
                
                # 詳細情報を取得
                local info
                info=$(get_log_group_info "$log_group_name")
                local retention=$(echo "$info" | cut -f1)
                local stored_bytes=$(echo "$info" | cut -f2)
                local creation_time=$(echo "$info" | cut -f3)
                
                if [[ "$retention" != "N/A" ]]; then
                    printf "    保持期間: %s日, サイズ: %s bytes\n" "$retention" "$stored_bytes"
                fi
                
                # テストモードの場合、テストログを送信
                if [[ "$test_mode" == "test" ]]; then
                    printf "    テストログ送信中... "
                    if send_test_log_event "$log_group_name"; then
                        echo -e "${GREEN}成功${NC}"
                    else
                        echo -e "${RED}失敗${NC}"
                        failed_groups=$((failed_groups + 1))
                    fi
                fi
            else
                echo -e "${RED}✗ 存在しません${NC}"
                failed_groups=$((failed_groups + 1))
            fi
        done
        
        echo ""
    done
    
    # サマリーを表示
    log_info "テスト結果サマリー"
    echo "===================="
    echo "総ログ グループ数: $total_groups"
    echo "存在するログ グループ数: $existing_groups"
    echo "存在しないログ グループ数: $((total_groups - existing_groups))"
    
    if [[ "$test_mode" == "test" ]]; then
        echo "テストログ送信失敗数: $failed_groups"
    fi
    
    # 成功率を計算
    local success_rate
    success_rate=$(echo "scale=1; $existing_groups * 100 / $total_groups" | bc -l)
    echo "成功率: ${success_rate}%"
    
    echo ""
    
    if [[ "$existing_groups" -eq "$total_groups" ]]; then
        log_info "すべてのログ グループが正常に設定されています！"
        
        if [[ "$test_mode" == "test" && "$failed_groups" -eq 0 ]]; then
            log_info "すべてのテストログ送信が成功しました！"
        fi
        
        exit 0
    else
        log_warn "一部のログ グループが見つかりません"
        log_info "CDKスタックがデプロイされているか確認してください："
        echo "  cdk list"
        echo "  cdk deploy --all"
        exit 1
    fi
}

# 使用方法を表示
show_usage() {
    cat << EOF
CloudWatch ログ設定テストスクリプト

使用方法:
  $0 [check|test]

コマンド:
  check    ログ グループの存在確認のみ実行（デフォルト）
  test     ログ グループの存在確認とテストログ送信を実行

環境変数:
  ENVIRONMENT    環境名（デフォルト: local）
  AWS_REGION     AWSリージョン（デフォルト: ap-northeast-1）

例:
  $0 check
  $0 test
  ENVIRONMENT=dev $0 check

EOF
}

# 引数解析
case "${1:-check}" in
    "check")
        main "check"
        ;;
    "test")
        main "test"
        ;;
    "--help"|"-h")
        show_usage
        exit 0
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
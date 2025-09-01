# GitLab Runner ローカルテスト用Makefile
# 便利なコマンドのショートカット

.PHONY: help setup start stop restart logs clean test validate list

# デフォルトターゲット
help:
	@echo "GitLab Runner ローカルテスト用コマンド:"
	@echo ""
	@echo "  setup     - 初期セットアップ"
	@echo "  start     - GitLab Runnerサービス開始"
	@echo "  stop      - GitLab Runnerサービス停止"
	@echo "  restart   - GitLab Runnerサービス再起動"
	@echo "  logs      - GitLab Runnerログ表示"
	@echo "  clean     - 全コンテナとボリュームを削除"
	@echo "  test      - 全ジョブをテスト実行"
	@echo "  validate  - .gitlab-ci.yml構文チェック"
	@echo "  list      - 利用可能なジョブ一覧"
	@echo ""
	@echo "個別ジョブ実行:"
	@echo "  make run JOB=lint     - lintジョブを実行"
	@echo "  make run JOB=test     - testジョブを実行"

# 初期セットアップ
setup:
	@echo "GitLab Runner環境のセットアップ中..."
	@docker-compose pull
	@mkdir -p cache
	@chmod +x ../scripts/test-gitlab-ci.sh
	@echo "セットアップが完了しました"

# GitLab Runnerサービス開始
start:
	@echo "GitLab Runnerサービスを開始中..."
	@docker-compose up -d
	@echo "GitLab Runnerが起動しました"

# GitLab Runnerサービス停止
stop:
	@echo "GitLab Runnerサービスを停止中..."
	@docker-compose down
	@echo "GitLab Runnerが停止しました"

# GitLab Runnerサービス再起動
restart: stop start

# ログ表示
logs:
	@docker-compose logs -f gitlab-runner

# クリーンアップ
clean:
	@echo "全コンテナとボリュームを削除中..."
	@docker-compose down -v --remove-orphans
	@docker system prune -f
	@echo "クリーンアップが完了しました"

# 全ジョブテスト実行
test:
	@echo "全ジョブをテスト実行中..."
	@../scripts/test-gitlab-ci.sh --docker

# 構文チェック
validate:
	@echo ".gitlab-ci.yml構文チェック中..."
	@../scripts/test-gitlab-ci.sh --validate

# ジョブ一覧表示
list:
	@echo "利用可能なジョブ一覧:"
	@../scripts/test-gitlab-ci.sh --list

# 個別ジョブ実行
run:
	@if [ -z "$(JOB)" ]; then \
		echo "使用方法: make run JOB=ジョブ名"; \
		echo "例: make run JOB=lint"; \
		exit 1; \
	fi
	@echo "ジョブ '$(JOB)' を実行中..."
	@docker-compose exec gitlab-runner gitlab-runner exec docker $(JOB)

# 開発用ショートカット
dev-setup: setup start
	@echo "開発環境が準備できました"

# CI/CDパイプライン全体のシミュレーション
simulate-pipeline:
	@echo "CI/CDパイプライン全体をシミュレーション中..."
	@echo "1. キャッシュ作成..."
	@make run JOB=cache || true
	@echo "2. 静的解析..."
	@make run JOB=lint || true
	@echo "3. ユニットテスト..."
	@make run JOB=test || true
	@echo "4. SCAチェック..."
	@make run JOB=sca || true
	@echo "5. SASTチェック..."
	@make run JOB=sast || true
	@echo "パイプラインシミュレーションが完了しました"

# ヘルスチェック
health:
	@echo "GitLab Runner環境のヘルスチェック中..."
	@docker-compose ps
	@docker-compose exec gitlab-runner gitlab-runner verify || echo "GitLab Runnerの設定を確認してください"
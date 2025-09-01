# マルチステージビルドでイメージサイズを最適化
FROM python:3.13-slim as builder

# 作業ディレクトリの設定
WORKDIR /app

# システムの依存関係をインストール
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Pythonの依存関係をインストール
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# 本番用イメージ
FROM python:3.13-slim

# 非rootユーザーを作成
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 作業ディレクトリの設定
WORKDIR /app

# システムの依存関係をインストール（最小限）
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# builderステージからPythonパッケージをコピー
COPY --from=builder /root/.local /home/appuser/.local

# アプリケーションコードをコピー
COPY . .

# 権限を設定
RUN chown -R appuser:appuser /app
USER appuser

# PATHを設定
ENV PATH=/home/appuser/.local/bin:$PATH

# 環境変数を設定
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# ポートを公開
EXPOSE 8000

# アプリケーションを起動
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
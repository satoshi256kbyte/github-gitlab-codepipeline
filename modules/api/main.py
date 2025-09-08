"""
FastAPI アプリケーションのメインファイル
CI/CDパイプライン比較用のシンプルなREST API
"""

from datetime import UTC, datetime
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .exceptions import (
    general_exception_handler,
    http_exception_handler,
    validation_exception_handler,
)

# ルーターとエラーハンドラーのインポート
from .routers import health, items, version


class Settings(BaseModel):
    """アプリケーション設定管理クラス"""

    app_name: str = "CI/CD Comparison API"
    version: str = "1.0.0"
    environment: str = "local"
    log_level: str = "INFO"

    class Config:
        env_prefix = "APP_"


# 設定インスタンスの作成
settings = Settings()

# FastAPIアプリケーションの作成
app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description="GitHub Actions、GitLab CI/CD、AWS CodePipelineの比較用API",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "*"
    ],  # 本番環境では適切なオリジンを設定  # nosemgrep: python.fastapi.security.wildcard-cors.wildcard-cors
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# エラーハンドラーの登録
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)

# ルーターの登録
app.include_router(health.router)
app.include_router(version.router)
app.include_router(items.router)


@app.get("/")
async def root() -> dict[str, Any]:
    """ルートエンドポイント"""
    return {
        "message": f"Welcome to {settings.app_name}",
        "version": settings.version,
        "environment": settings.environment,
        "timestamp": datetime.now(UTC).isoformat(),
    }


# Lambda ハンドラー
def lambda_handler(event, context):
    """AWS Lambda用のハンドラー関数"""
    from mangum import Mangum

    # Mangumを使用してFastAPIアプリケーションをLambda対応にする
    handler = Mangum(app, lifespan="off")
    return handler(event, context)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level=settings.log_level.lower(),
    )

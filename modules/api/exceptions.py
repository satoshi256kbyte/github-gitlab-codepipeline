"""
エラーハンドリング
"""

from datetime import UTC, datetime

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .models.schemas import ErrorResponse


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """
    HTTPエラーハンドラー
    """
    # 標準のFastAPI形式も含める
    content = {
        "detail": exc.detail,
        "error": f"HTTP_{exc.status_code}",
        "message": exc.detail,
        "timestamp": datetime.now(UTC).isoformat(),
    }

    return JSONResponse(status_code=exc.status_code, content=content)


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """
    バリデーションエラーハンドラー
    """
    error_messages = []
    for error in exc.errors():
        field = " -> ".join(str(loc) for loc in error["loc"])
        message = error["msg"]
        error_messages.append(f"{field}: {message}")

    # 標準のFastAPI形式も含める
    content = {
        "detail": exc.errors(),  # 標準のFastAPI形式
        "error": "VALIDATION_ERROR",
        "message": "; ".join(error_messages),
        "timestamp": datetime.now(UTC).isoformat(),
    }

    return JSONResponse(status_code=422, content=content)


async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    一般的なエラーハンドラー
    """
    error_response = ErrorResponse(
        error="INTERNAL_SERVER_ERROR",
        message="内部サーバーエラーが発生しました",
        timestamp=datetime.now(UTC),
    )

    return JSONResponse(status_code=500, content=error_response.model_dump(mode="json"))

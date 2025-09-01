"""
エラーハンドリング
"""

from datetime import datetime
from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from .models.schemas import ErrorResponse


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """
    HTTPエラーハンドラー
    """
    error_response = ErrorResponse(
        error=f"HTTP_{exc.status_code}",
        message=exc.detail,
        timestamp=datetime.utcnow()
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.dict()
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    バリデーションエラーハンドラー
    """
    error_messages = []
    for error in exc.errors():
        field = " -> ".join(str(loc) for loc in error["loc"])
        message = error["msg"]
        error_messages.append(f"{field}: {message}")
    
    error_response = ErrorResponse(
        error="VALIDATION_ERROR",
        message="; ".join(error_messages),
        timestamp=datetime.utcnow()
    )
    
    return JSONResponse(
        status_code=422,
        content=error_response.dict()
    )


async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    一般的なエラーハンドラー
    """
    error_response = ErrorResponse(
        error="INTERNAL_SERVER_ERROR",
        message="内部サーバーエラーが発生しました",
        timestamp=datetime.utcnow()
    )
    
    return JSONResponse(
        status_code=500,
        content=error_response.dict()
    )
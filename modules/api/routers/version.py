"""
バージョン情報エンドポイント
"""

import os
from datetime import datetime
from fastapi import APIRouter
from ..models.schemas import VersionResponse

router = APIRouter()


@router.get("/version", response_model=VersionResponse, tags=["Version"])
async def get_version() -> VersionResponse:
    """
    バージョン情報エンドポイント
    アプリケーションのバージョン情報を取得する
    """
    return VersionResponse(
        version="1.0.0",
        build_time=datetime.utcnow(),
        commit_hash=os.getenv("COMMIT_HASH", "unknown"),
        environment=os.getenv("APP_ENVIRONMENT", "local")
    )
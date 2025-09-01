"""
ヘルスチェックエンドポイント
"""

from datetime import datetime
from fastapi import APIRouter
from ..models.schemas import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check() -> HealthResponse:
    """
    ヘルスチェックエンドポイント
    アプリケーションの稼働状況を確認する
    """
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        service="CI/CD Comparison API"
    )
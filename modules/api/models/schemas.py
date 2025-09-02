"""
Pydanticデータモデル定義
API リクエスト・レスポンス用のスキーマ
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class HealthResponse(BaseModel):
    """ヘルスチェックレスポンスモデル"""

    status: str = "healthy"
    timestamp: datetime
    service: str = "CI/CD Comparison API"

    model_config = ConfigDict(json_encoders={datetime: lambda v: v.isoformat()})


class VersionResponse(BaseModel):
    """バージョン情報レスポンスモデル"""

    version: str
    build_time: datetime
    commit_hash: str | None = None
    environment: str

    model_config = ConfigDict(json_encoders={datetime: lambda v: v.isoformat()})


class ItemBase(BaseModel):
    """アイテムベースモデル"""

    name: str = Field(..., min_length=1, max_length=100, description="アイテム名")
    description: str = Field(
        ..., min_length=1, max_length=500, description="アイテム説明"
    )

    @field_validator("name")
    @classmethod
    def validate_name(cls, v):
        if not v or not v.strip():
            raise ValueError("名前は空白のみにはできません")
        if len(v.strip()) > 100:
            raise ValueError("名前は100文字以内で入力してください")
        return v.strip()

    @field_validator("description")
    @classmethod
    def validate_description(cls, v):
        if not v or not v.strip():
            raise ValueError("説明は空白のみにはできません")
        if len(v.strip()) > 500:
            raise ValueError("説明は500文字以内で入力してください")
        return v.strip()


class ItemCreate(ItemBase):
    """アイテム作成用モデル"""

    pass


class ItemUpdate(BaseModel):
    """アイテム更新用モデル"""

    name: str | None = Field(
        None, min_length=1, max_length=100, description="アイテム名"
    )
    description: str | None = Field(
        None, min_length=1, max_length=500, description="アイテム説明"
    )

    @field_validator("name")
    @classmethod
    def validate_name(cls, v):
        if v is not None and not v.strip():
            raise ValueError("名前は空白のみにはできません")
        return v.strip() if v else v

    @field_validator("description")
    @classmethod
    def validate_description(cls, v):
        if v is not None and not v.strip():
            raise ValueError("説明は空白のみにはできません")
        return v.strip() if v else v


class Item(ItemBase):
    """アイテムレスポンスモデル"""

    id: int = Field(..., description="アイテムID")
    created_at: datetime = Field(..., description="作成日時")
    updated_at: datetime | None = Field(None, description="更新日時")

    model_config = ConfigDict(json_encoders={datetime: lambda v: v.isoformat()})


class ItemList(BaseModel):
    """アイテム一覧レスポンスモデル"""

    items: list[Item]
    total: int = Field(..., description="総件数")


class ErrorResponse(BaseModel):
    """エラーレスポンスモデル"""

    error: str = Field(..., description="エラーコード")
    message: str = Field(..., description="エラーメッセージ")
    timestamp: datetime = Field(..., description="エラー発生時刻")

    model_config = ConfigDict(json_encoders={datetime: lambda v: v.isoformat()})

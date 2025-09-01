"""
Pydanticデータモデル定義
API リクエスト・レスポンス用のスキーマ
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, validator


class HealthResponse(BaseModel):
    """ヘルスチェックレスポンスモデル"""
    status: str = "healthy"
    timestamp: datetime
    service: str = "CI/CD Comparison API"
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class VersionResponse(BaseModel):
    """バージョン情報レスポンスモデル"""
    version: str
    build_time: datetime
    commit_hash: Optional[str] = None
    environment: str
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class ItemBase(BaseModel):
    """アイテムベースモデル"""
    name: str = Field(..., min_length=1, max_length=100, description="アイテム名")
    description: str = Field(..., min_length=1, max_length=500, description="アイテム説明")
    
    @validator('name')
    def validate_name(cls, v):
        if not v.strip():
            raise ValueError('名前は空白のみにはできません')
        return v.strip()
    
    @validator('description')
    def validate_description(cls, v):
        if not v.strip():
            raise ValueError('説明は空白のみにはできません')
        return v.strip()


class ItemCreate(ItemBase):
    """アイテム作成用モデル"""
    pass


class ItemUpdate(BaseModel):
    """アイテム更新用モデル"""
    name: Optional[str] = Field(None, min_length=1, max_length=100, description="アイテム名")
    description: Optional[str] = Field(None, min_length=1, max_length=500, description="アイテム説明")
    
    @validator('name')
    def validate_name(cls, v):
        if v is not None and not v.strip():
            raise ValueError('名前は空白のみにはできません')
        return v.strip() if v else v
    
    @validator('description')
    def validate_description(cls, v):
        if v is not None and not v.strip():
            raise ValueError('説明は空白のみにはできません')
        return v.strip() if v else v


class Item(ItemBase):
    """アイテムレスポンスモデル"""
    id: int = Field(..., description="アイテムID")
    created_at: datetime = Field(..., description="作成日時")
    updated_at: Optional[datetime] = Field(None, description="更新日時")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class ItemList(BaseModel):
    """アイテム一覧レスポンスモデル"""
    items: List[Item]
    total: int = Field(..., description="総件数")
    
    
class ErrorResponse(BaseModel):
    """エラーレスポンスモデル"""
    error: str = Field(..., description="エラーコード")
    message: str = Field(..., description="エラーメッセージ")
    timestamp: datetime = Field(..., description="エラー発生時刻")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
"""
データモデルのテスト
"""

from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from ..models.schemas import (
    ErrorResponse,
    HealthResponse,
    Item,
    ItemCreate,
    ItemList,
    ItemUpdate,
    VersionResponse,
)


class TestHealthResponse:
    """HealthResponseモデルのテスト"""

    def test_valid_health_response(self):
        """有効なヘルスレスポンスの作成テスト"""
        timestamp = datetime.now(UTC)
        response = HealthResponse(
            status="healthy", timestamp=timestamp, service="Test Service"
        )

        assert response.status == "healthy"
        assert response.timestamp == timestamp
        assert response.service == "Test Service"

    def test_default_values(self):
        """デフォルト値のテスト"""
        timestamp = datetime.now(UTC)
        response = HealthResponse(timestamp=timestamp)

        assert response.status == "healthy"
        assert response.service == "CI/CD Comparison API"


class TestVersionResponse:
    """VersionResponseモデルのテスト"""

    def test_valid_version_response(self):
        """有効なバージョンレスポンスの作成テスト"""
        build_time = datetime.now(UTC)
        response = VersionResponse(
            version="1.0.0",
            build_time=build_time,
            commit_hash="abc123",
            environment="test",
        )

        assert response.version == "1.0.0"
        assert response.build_time == build_time
        assert response.commit_hash == "abc123"
        assert response.environment == "test"

    def test_optional_commit_hash(self):
        """commit_hashがオプショナルであることのテスト"""
        build_time = datetime.now(UTC)
        response = VersionResponse(
            version="1.0.0", build_time=build_time, environment="test"
        )

        assert response.commit_hash is None


class TestItemCreate:
    """ItemCreateモデルのテスト"""

    def test_valid_item_create(self):
        """有効なアイテム作成データのテスト"""
        item = ItemCreate(name="テストアイテム", description="テスト用の説明")

        assert item.name == "テストアイテム"
        assert item.description == "テスト用の説明"

    def test_name_validation_empty(self):
        """名前の空文字列バリデーションテスト"""
        with pytest.raises(ValidationError) as exc_info:
            ItemCreate(name="", description="説明")

        errors = exc_info.value.errors()
        assert any(
            error["type"] in ["string_too_short", "value_error"] for error in errors
        )

    def test_name_validation_whitespace_only(self):
        """名前の空白のみバリデーションテスト"""
        with pytest.raises(ValidationError) as exc_info:
            ItemCreate(name="   ", description="説明")

        errors = exc_info.value.errors()
        assert any("空白のみにはできません" in str(error) for error in errors)

    def test_name_too_long(self):
        """名前の長さ制限テスト"""
        with pytest.raises(ValidationError) as exc_info:
            ItemCreate(name="a" * 101, description="説明")

        errors = exc_info.value.errors()
        assert any(
            error["type"] in ["string_too_long", "value_error"] for error in errors
        )

    def test_description_validation_empty(self):
        """説明の空文字列バリデーションテスト"""
        with pytest.raises(ValidationError) as exc_info:
            ItemCreate(name="名前", description="")

        errors = exc_info.value.errors()
        assert any(
            error["type"] in ["string_too_short", "value_error"] for error in errors
        )

    def test_description_too_long(self):
        """説明の長さ制限テスト"""
        with pytest.raises(ValidationError) as exc_info:
            ItemCreate(name="名前", description="a" * 501)

        errors = exc_info.value.errors()
        assert any(
            error["type"] in ["string_too_long", "value_error"] for error in errors
        )

    def test_name_trimming(self):
        """名前の前後空白除去テスト"""
        item = ItemCreate(name="  テストアイテム  ", description="  テスト用の説明  ")

        assert item.name == "テストアイテム"
        assert item.description == "テスト用の説明"


class TestItemUpdate:
    """ItemUpdateモデルのテスト"""

    def test_valid_item_update(self):
        """有効なアイテム更新データのテスト"""
        item = ItemUpdate(name="更新されたアイテム", description="更新された説明")

        assert item.name == "更新されたアイテム"
        assert item.description == "更新された説明"

    def test_partial_update(self):
        """部分更新のテスト"""
        item = ItemUpdate(name="新しい名前")

        assert item.name == "新しい名前"
        assert item.description is None

    def test_empty_update(self):
        """空の更新データのテスト"""
        item = ItemUpdate()

        assert item.name is None
        assert item.description is None

    def test_name_validation_whitespace_only(self):
        """名前の空白のみバリデーションテスト"""
        with pytest.raises(ValidationError) as exc_info:
            ItemUpdate(name="   ")

        errors = exc_info.value.errors()
        assert any("空白のみにはできません" in str(error) for error in errors)


class TestItem:
    """Itemモデルのテスト"""

    def test_valid_item(self):
        """有効なアイテムのテスト"""
        created_at = datetime.now(UTC)
        updated_at = datetime.now(UTC)

        item = Item(
            id=1,
            name="テストアイテム",
            description="テスト用の説明",
            created_at=created_at,
            updated_at=updated_at,
        )

        assert item.id == 1
        assert item.name == "テストアイテム"
        assert item.description == "テスト用の説明"
        assert item.created_at == created_at
        assert item.updated_at == updated_at

    def test_item_without_updated_at(self):
        """updated_atがNoneのアイテムのテスト"""
        created_at = datetime.now(UTC)

        item = Item(
            id=1,
            name="テストアイテム",
            description="テスト用の説明",
            created_at=created_at,
        )

        assert item.updated_at is None


class TestItemList:
    """ItemListモデルのテスト"""

    def test_valid_item_list(self):
        """有効なアイテムリストのテスト"""
        created_at = datetime.now(UTC)
        items = [
            Item(id=1, name="アイテム1", description="説明1", created_at=created_at),
            Item(id=2, name="アイテム2", description="説明2", created_at=created_at),
        ]

        item_list = ItemList(items=items, total=2)

        assert len(item_list.items) == 2
        assert item_list.total == 2

    def test_empty_item_list(self):
        """空のアイテムリストのテスト"""
        item_list = ItemList(items=[], total=0)

        assert len(item_list.items) == 0
        assert item_list.total == 0


class TestErrorResponse:
    """ErrorResponseモデルのテスト"""

    def test_valid_error_response(self):
        """有効なエラーレスポンスのテスト"""
        timestamp = datetime.now(UTC)
        error = ErrorResponse(
            error="NOT_FOUND", message="リソースが見つかりません", timestamp=timestamp
        )

        assert error.error == "NOT_FOUND"
        assert error.message == "リソースが見つかりません"
        assert error.timestamp == timestamp

"""
pytest設定ファイル
テスト用のフィクスチャとモックを定義
"""

from collections.abc import Generator
from datetime import datetime
from typing import Any
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from ..main import app
from ..routers.items import items_storage


@pytest.fixture
def client() -> TestClient:
    """
    FastAPIテストクライアントのフィクスチャ
    """
    return TestClient(app)


@pytest.fixture
def clean_items_storage() -> Generator[None]:
    """
    アイテムストレージをクリーンアップするフィクスチャ
    テスト実行前後でストレージを初期化する
    """
    # テスト前の状態を保存
    original_storage = items_storage.copy()

    # next_idをリセット
    from ..routers import items

    original_next_id = items.next_id
    items.next_id = 1

    # ストレージをクリア
    items_storage.clear()

    # テスト実行
    yield

    # テスト後に元の状態に復元
    items_storage.clear()
    items_storage.update(original_storage)
    items.next_id = original_next_id


@pytest.fixture
def sample_item_data() -> dict[str, Any]:
    """
    テスト用のサンプルアイテムデータ
    """
    return {"name": "テストアイテム", "description": "これはテスト用のアイテムです"}


@pytest.fixture
def sample_item_update_data() -> dict[str, Any]:
    """
    テスト用のアイテム更新データ
    """
    return {
        "name": "更新されたアイテム",
        "description": "これは更新されたテスト用のアイテムです",
    }


@pytest.fixture
def mock_datetime():
    """
    datetime.now(UTC)をモックするフィクスチャ
    """
    from datetime import UTC

    fixed_datetime = datetime(2024, 1, 1, 12, 0, 0, tzinfo=UTC)
    with patch("modules.api.routers.health.datetime") as mock_dt:
        mock_dt.now.return_value = fixed_datetime
        yield mock_dt


@pytest.fixture
def mock_environment_variables():
    """
    環境変数をモックするフィクスチャ
    """
    with patch.dict(
        "os.environ", {"COMMIT_HASH": "abc123def456", "APP_ENVIRONMENT": "test"}
    ):
        yield


@pytest.fixture(autouse=True)
def reset_items_storage():
    """
    各テスト実行前にアイテムストレージをリセットする
    autouse=Trueにより、全てのテストで自動実行される
    """
    # テスト開始前にリセット
    items_storage.clear()
    import modules.api.routers.items as items_module

    items_module.next_id = 1

    yield

    # テスト終了後にもクリア
    items_storage.clear()
    items_module.next_id = 1


class TestDataFactory:
    """
    テストデータ作成用のファクトリークラス
    """

    @staticmethod
    def create_item_data(
        name: str = "テストアイテム", description: str = "テスト用の説明"
    ) -> dict[str, str]:
        """アイテム作成用データを生成"""
        return {"name": name, "description": description}

    @staticmethod
    def create_invalid_item_data() -> dict[str, str]:
        """無効なアイテムデータを生成"""
        return {
            "name": "",  # 空文字列
            "description": "",  # 空文字列
        }

    @staticmethod
    def create_long_item_data() -> dict[str, str]:
        """長すぎるデータを持つアイテムデータを生成"""
        return {
            "name": "a" * 101,  # 100文字制限を超える
            "description": "b" * 501,  # 500文字制限を超える
        }


@pytest.fixture
def test_data_factory() -> TestDataFactory:
    """
    テストデータファクトリーのフィクスチャ
    """
    return TestDataFactory()

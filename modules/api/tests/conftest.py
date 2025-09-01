"""
pytest設定ファイル
テスト用のフィクスチャとモックを定義
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch
from datetime import datetime
from typing import Generator, Dict, Any

from ..main import app, settings
from ..routers.items import items_storage, next_id


@pytest.fixture
def client() -> TestClient:
    """
    FastAPIテストクライアントのフィクスチャ
    """
    return TestClient(app)


@pytest.fixture
def clean_items_storage() -> Generator[None, None, None]:
    """
    アイテムストレージをクリーンアップするフィクスチャ
    テスト実行前後でストレージを初期化する
    """
    # テスト前の状態を保存
    original_storage = items_storage.copy()
    original_next_id = next_id
    
    # ストレージをクリア
    items_storage.clear()
    
    # テスト実行
    yield
    
    # テスト後に元の状態に復元
    items_storage.clear()
    items_storage.update(original_storage)
    # next_idはグローバル変数なので直接変更できないため、
    # テストでは新しいアイテム作成時に適切にIDを管理する


@pytest.fixture
def sample_item_data() -> Dict[str, Any]:
    """
    テスト用のサンプルアイテムデータ
    """
    return {
        "name": "テストアイテム",
        "description": "これはテスト用のアイテムです"
    }


@pytest.fixture
def sample_item_update_data() -> Dict[str, Any]:
    """
    テスト用のアイテム更新データ
    """
    return {
        "name": "更新されたアイテム",
        "description": "これは更新されたテスト用のアイテムです"
    }


@pytest.fixture
def mock_datetime():
    """
    datetime.utcnow()をモックするフィクスチャ
    """
    fixed_datetime = datetime(2024, 1, 1, 12, 0, 0)
    with patch('modules.api.routers.health.datetime') as mock_dt:
        mock_dt.utcnow.return_value = fixed_datetime
        yield mock_dt


@pytest.fixture
def mock_environment_variables():
    """
    環境変数をモックするフィクスチャ
    """
    with patch.dict('os.environ', {
        'COMMIT_HASH': 'abc123def456',
        'APP_ENVIRONMENT': 'test'
    }):
        yield


@pytest.fixture(autouse=True)
def reset_items_storage():
    """
    各テスト実行前にアイテムストレージをリセットする
    autouse=Trueにより、全てのテストで自動実行される
    """
    items_storage.clear()
    # next_idのリセットは各テストで個別に管理
    yield
    items_storage.clear()


class TestDataFactory:
    """
    テストデータ作成用のファクトリークラス
    """
    
    @staticmethod
    def create_item_data(
        name: str = "テストアイテム",
        description: str = "テスト用の説明"
    ) -> Dict[str, str]:
        """アイテム作成用データを生成"""
        return {
            "name": name,
            "description": description
        }
    
    @staticmethod
    def create_invalid_item_data() -> Dict[str, str]:
        """無効なアイテムデータを生成"""
        return {
            "name": "",  # 空文字列
            "description": ""  # 空文字列
        }
    
    @staticmethod
    def create_long_item_data() -> Dict[str, str]:
        """長すぎるデータを持つアイテムデータを生成"""
        return {
            "name": "a" * 101,  # 100文字制限を超える
            "description": "b" * 501  # 500文字制限を超える
        }


@pytest.fixture
def test_data_factory() -> TestDataFactory:
    """
    テストデータファクトリーのフィクスチャ
    """
    return TestDataFactory()
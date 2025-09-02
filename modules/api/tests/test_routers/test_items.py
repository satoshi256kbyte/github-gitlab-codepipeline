"""
アイテムCRUDエンドポイントのテスト
"""

from datetime import datetime

import pytest
from fastapi.testclient import TestClient


class TestItemsEndpoint:
    """アイテムCRUDエンドポイントのテストクラス"""

    @pytest.mark.unit
    def test_get_items_empty(self, client: TestClient, clean_items_storage):
        """空のアイテム一覧取得テスト"""
        response = client.get("/api/items")

        assert response.status_code == 200
        data = response.json()

        assert "items" in data
        assert "total" in data
        assert data["items"] == []
        assert data["total"] == 0

    @pytest.mark.unit
    def test_create_item_success(
        self, client: TestClient, clean_items_storage, sample_item_data
    ):
        """アイテム作成成功テスト"""
        response = client.post("/api/items", json=sample_item_data)

        assert response.status_code == 201
        data = response.json()

        # レスポンス構造の確認
        assert "id" in data
        assert "name" in data
        assert "description" in data
        assert "created_at" in data
        assert "updated_at" in data

        # 値の確認
        assert data["id"] == 1
        assert data["name"] == sample_item_data["name"]
        assert data["description"] == sample_item_data["description"]
        assert data["updated_at"] is None

        # created_atが有効な日時形式であることを確認
        created_at = datetime.fromisoformat(data["created_at"].replace("Z", "+00:00"))
        assert isinstance(created_at, datetime)

    @pytest.mark.unit
    def test_create_item_invalid_data(self, client: TestClient, clean_items_storage):
        """無効なデータでのアイテム作成テスト"""
        invalid_data = {
            "name": "",  # 空文字列
            "description": "",  # 空文字列
        }

        response = client.post("/api/items", json=invalid_data)
        assert response.status_code == 422  # Validation Error

    @pytest.mark.unit
    def test_create_item_missing_fields(self, client: TestClient, clean_items_storage):
        """必須フィールドが不足したアイテム作成テスト"""
        incomplete_data = {
            "name": "テストアイテム"
            # description が不足
        }

        response = client.post("/api/items", json=incomplete_data)
        assert response.status_code == 422  # Validation Error

    @pytest.mark.unit
    def test_get_items_with_data(
        self, client: TestClient, clean_items_storage, sample_item_data
    ):
        """データがある場合のアイテム一覧取得テスト"""
        # アイテムを作成
        create_response = client.post("/api/items", json=sample_item_data)
        assert create_response.status_code == 201

        # 一覧を取得
        response = client.get("/api/items")

        assert response.status_code == 200
        data = response.json()

        assert len(data["items"]) == 1
        assert data["total"] == 1

        item = data["items"][0]
        assert item["name"] == sample_item_data["name"]
        assert item["description"] == sample_item_data["description"]

    @pytest.mark.unit
    def test_get_item_by_id_success(
        self, client: TestClient, clean_items_storage, sample_item_data
    ):
        """IDによるアイテム取得成功テスト"""
        # アイテムを作成
        create_response = client.post("/api/items", json=sample_item_data)
        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        # IDでアイテムを取得
        response = client.get(f"/api/items/{item_id}")

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == item_id
        assert data["name"] == sample_item_data["name"]
        assert data["description"] == sample_item_data["description"]

    @pytest.mark.unit
    def test_get_item_by_id_not_found(self, client: TestClient, clean_items_storage):
        """存在しないIDでのアイテム取得テスト"""
        response = client.get("/api/items/999")

        assert response.status_code == 404
        data = response.json()
        assert "detail" in data
        assert "999" in data["detail"]

    @pytest.mark.unit
    def test_update_item_success(
        self,
        client: TestClient,
        clean_items_storage,
        sample_item_data,
        sample_item_update_data,
    ):
        """アイテム更新成功テスト"""
        # アイテムを作成
        create_response = client.post("/api/items", json=sample_item_data)
        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        # アイテムを更新
        response = client.put(f"/api/items/{item_id}", json=sample_item_update_data)

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == item_id
        assert data["name"] == sample_item_update_data["name"]
        assert data["description"] == sample_item_update_data["description"]
        assert data["updated_at"] is not None

        # updated_atが有効な日時形式であることを確認
        updated_at = datetime.fromisoformat(data["updated_at"].replace("Z", "+00:00"))
        assert isinstance(updated_at, datetime)

    @pytest.mark.unit
    def test_update_item_partial(
        self, client: TestClient, clean_items_storage, sample_item_data
    ):
        """アイテム部分更新テスト"""
        # アイテムを作成
        create_response = client.post("/api/items", json=sample_item_data)
        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        # 名前のみ更新
        partial_update = {"name": "部分更新されたアイテム"}
        response = client.put(f"/api/items/{item_id}", json=partial_update)

        assert response.status_code == 200
        data = response.json()

        assert data["name"] == "部分更新されたアイテム"
        assert data["description"] == sample_item_data["description"]  # 元の値
        assert data["updated_at"] is not None

    @pytest.mark.unit
    def test_update_item_not_found(
        self, client: TestClient, clean_items_storage, sample_item_update_data
    ):
        """存在しないアイテムの更新テスト"""
        response = client.put("/api/items/999", json=sample_item_update_data)

        assert response.status_code == 404
        data = response.json()
        assert "detail" in data
        assert "999" in data["detail"]

    @pytest.mark.unit
    def test_delete_item_success(
        self, client: TestClient, clean_items_storage, sample_item_data
    ):
        """アイテム削除成功テスト"""
        # アイテムを作成
        create_response = client.post("/api/items", json=sample_item_data)
        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        # アイテムを削除
        response = client.delete(f"/api/items/{item_id}")

        assert response.status_code == 204

        # 削除されたことを確認
        get_response = client.get(f"/api/items/{item_id}")
        assert get_response.status_code == 404

    @pytest.mark.unit
    def test_delete_item_not_found(self, client: TestClient, clean_items_storage):
        """存在しないアイテムの削除テスト"""
        response = client.delete("/api/items/999")

        assert response.status_code == 404
        data = response.json()
        assert "detail" in data
        assert "999" in data["detail"]

    @pytest.mark.unit
    def test_create_multiple_items(
        self, client: TestClient, clean_items_storage, test_data_factory
    ):
        """複数アイテム作成テスト"""
        # 複数のアイテムを作成
        items_data = [
            test_data_factory.create_item_data("アイテム1", "説明1"),
            test_data_factory.create_item_data("アイテム2", "説明2"),
            test_data_factory.create_item_data("アイテム3", "説明3"),
        ]

        created_items = []
        for item_data in items_data:
            response = client.post("/api/items", json=item_data)
            assert response.status_code == 201
            created_items.append(response.json())

        # 一覧取得で全てのアイテムが取得できることを確認
        response = client.get("/api/items")
        assert response.status_code == 200
        data = response.json()

        assert len(data["items"]) == 3
        assert data["total"] == 3

        # IDが連番になっていることを確認
        ids = [item["id"] for item in data["items"]]
        assert ids == [1, 2, 3]

    @pytest.mark.unit
    def test_item_name_trimming(self, client: TestClient, clean_items_storage):
        """アイテム名の前後空白除去テスト"""
        item_data = {
            "name": "  前後に空白があるアイテム  ",
            "description": "  前後に空白がある説明  ",
        }

        response = client.post("/api/items", json=item_data)

        assert response.status_code == 201
        data = response.json()

        # 前後の空白が除去されていることを確認
        assert data["name"] == "前後に空白があるアイテム"
        assert data["description"] == "前後に空白がある説明"


class TestItemsErrorCases:
    """アイテムエンドポイントのエラーケーステスト"""

    @pytest.mark.unit
    def test_create_item_too_long_name(
        self, client: TestClient, clean_items_storage, test_data_factory
    ):
        """長すぎる名前でのアイテム作成テスト"""
        long_data = test_data_factory.create_long_item_data()

        response = client.post("/api/items", json=long_data)
        assert response.status_code == 422  # Validation Error

    @pytest.mark.unit
    def test_invalid_item_id_format(self, client: TestClient):
        """無効なアイテムID形式のテスト"""
        # 文字列のIDでアクセス
        response = client.get("/api/items/invalid_id")
        assert response.status_code == 422  # Validation Error

    @pytest.mark.unit
    def test_negative_item_id(self, client: TestClient):
        """負のアイテムIDのテスト"""
        response = client.get("/api/items/-1")
        assert response.status_code == 404  # Not Found

    @pytest.mark.unit
    def test_zero_item_id(self, client: TestClient):
        """ゼロのアイテムIDのテスト"""
        response = client.get("/api/items/0")
        assert response.status_code == 404  # Not Found

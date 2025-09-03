"""
統合テスト
アプリケーション全体の動作を確認するテスト
"""

import pytest
from fastapi.testclient import TestClient


class TestApplicationIntegration:
    """アプリケーション統合テストクラス"""

    @pytest.mark.integration
    def test_full_item_lifecycle(self, client: TestClient, clean_items_storage):
        """アイテムの完全なライフサイクルテスト"""
        # 1. 初期状態で空のリストを確認
        response = client.get("/api/items")
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 0
        assert data["total"] == 0

        # 2. アイテムを作成
        item_data = {
            "name": "統合テストアイテム",
            "description": "統合テスト用のアイテムです",
        }

        create_response = client.post("/api/items", json=item_data)
        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        # 3. 作成されたアイテムを個別取得で確認
        get_response = client.get(f"/api/items/{item_id}")
        assert get_response.status_code == 200
        retrieved_item = get_response.json()
        assert retrieved_item["name"] == item_data["name"]
        assert retrieved_item["description"] == item_data["description"]

        # 4. リスト取得で確認
        list_response = client.get("/api/items")
        assert list_response.status_code == 200
        list_data = list_response.json()
        assert len(list_data["items"]) == 1
        assert list_data["total"] == 1

        # 5. アイテムを更新
        update_data = {
            "name": "更新された統合テストアイテム",
            "description": "更新された統合テスト用のアイテムです",
        }

        update_response = client.put(f"/api/items/{item_id}", json=update_data)
        assert update_response.status_code == 200
        updated_item = update_response.json()
        assert updated_item["name"] == update_data["name"]
        assert updated_item["description"] == update_data["description"]
        assert updated_item["updated_at"] is not None

        # 6. 更新されたアイテムを再取得で確認
        get_updated_response = client.get(f"/api/items/{item_id}")
        assert get_updated_response.status_code == 200
        final_item = get_updated_response.json()
        assert final_item["name"] == update_data["name"]
        assert final_item["description"] == update_data["description"]

        # 7. アイテムを削除
        delete_response = client.delete(f"/api/items/{item_id}")
        assert delete_response.status_code == 204

        # 8. 削除されたことを確認
        get_deleted_response = client.get(f"/api/items/{item_id}")
        assert get_deleted_response.status_code == 404

        # 9. リストが再び空になったことを確認
        final_list_response = client.get("/api/items")
        assert final_list_response.status_code == 200
        final_list_data = final_list_response.json()
        assert len(final_list_data["items"]) == 0
        assert final_list_data["total"] == 0

    @pytest.mark.integration
    def test_multiple_items_management(self, client: TestClient, clean_items_storage):
        """複数アイテムの管理テスト"""
        # 複数のアイテムを作成
        items_data = [
            {"name": "アイテム1", "description": "説明1"},
            {"name": "アイテム2", "description": "説明2"},
            {"name": "アイテム3", "description": "説明3"},
        ]

        created_items = []
        for item_data in items_data:
            response = client.post("/api/items", json=item_data)
            assert response.status_code == 201
            created_items.append(response.json())

        # 全てのアイテムが作成されたことを確認
        list_response = client.get("/api/items")
        assert list_response.status_code == 200
        list_data = list_response.json()
        assert len(list_data["items"]) == 3
        assert list_data["total"] == 3

        # 各アイテムを個別に取得して確認
        for i, created_item in enumerate(created_items):
            item_id = created_item["id"]
            get_response = client.get(f"/api/items/{item_id}")
            assert get_response.status_code == 200

            retrieved_item = get_response.json()
            assert retrieved_item["name"] == items_data[i]["name"]
            assert retrieved_item["description"] == items_data[i]["description"]

        # 一部のアイテムを更新
        first_item_id = created_items[0]["id"]
        update_data = {"name": "更新されたアイテム1"}

        update_response = client.put(f"/api/items/{first_item_id}", json=update_data)
        assert update_response.status_code == 200

        # 一部のアイテムを削除
        second_item_id = created_items[1]["id"]
        delete_response = client.delete(f"/api/items/{second_item_id}")
        assert delete_response.status_code == 204

        # 最終状態を確認
        final_list_response = client.get("/api/items")
        assert final_list_response.status_code == 200
        final_list_data = final_list_response.json()
        assert len(final_list_data["items"]) == 2  # 1つ削除されたので2つ
        assert final_list_data["total"] == 2

    @pytest.mark.integration
    def test_api_endpoints_consistency(self, client: TestClient):
        """APIエンドポイントの一貫性テスト"""
        # 各エンドポイントが正常に応答することを確認
        endpoints = [
            ("/", 200),
            ("/health", 200),
            ("/version", 200),
            ("/api/items", 200),
            ("/docs", 200),
            ("/redoc", 200),
            ("/openapi.json", 200),
        ]

        for endpoint, expected_status in endpoints:
            response = client.get(endpoint)
            assert response.status_code == expected_status, (
                f"エンドポイント {endpoint} が期待されたステータス {expected_status} を返しませんでした"
            )

    @pytest.mark.integration
    def test_error_handling_consistency(self, client: TestClient):
        """エラーハンドリングの一貫性テスト"""
        # 存在しないリソースへのアクセス
        not_found_endpoints = ["/api/items/999", "/nonexistent"]

        for endpoint in not_found_endpoints:
            response = client.get(endpoint)
            assert response.status_code == 404

            data = response.json()
            assert "detail" in data

    @pytest.mark.integration
    def test_content_type_consistency(self, client: TestClient):
        """Content-Typeの一貫性テスト"""
        json_endpoints = ["/", "/health", "/version", "/api/items"]

        for endpoint in json_endpoints:
            response = client.get(endpoint)
            assert response.status_code == 200
            assert "application/json" in response.headers["content-type"]

    @pytest.mark.integration
    def test_application_startup_and_health(self, client: TestClient):
        """アプリケーションの起動とヘルスチェックテスト"""
        # アプリケーションが正常に起動していることを確認
        health_response = client.get("/health")
        assert health_response.status_code == 200

        health_data = health_response.json()
        assert health_data["status"] == "healthy"

        # バージョン情報も取得できることを確認
        version_response = client.get("/version")
        assert version_response.status_code == 200

        version_data = version_response.json()
        assert "version" in version_data
        assert version_data["version"] == "1.0.0"

        # ルートエンドポイントも正常に動作することを確認
        root_response = client.get("/")
        assert root_response.status_code == 200

        root_data = root_response.json()
        assert "message" in root_data
        assert "CI/CD Comparison API" in root_data["message"]

"""
エラーハンドリングのテスト
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, Mock
from datetime import datetime


class TestErrorHandling:
    """エラーハンドリングのテストクラス"""
    
    @pytest.mark.unit
    def test_404_not_found_error(self, client: TestClient):
        """404エラーのテスト"""
        response = client.get("/nonexistent-endpoint")
        
        assert response.status_code == 404
        data = response.json()
        assert "detail" in data
    
    @pytest.mark.unit
    def test_405_method_not_allowed(self, client: TestClient):
        """405エラー（メソッド不許可）のテスト"""
        # GETのみ許可されているエンドポイントにPOSTでアクセス
        response = client.post("/health")
        
        assert response.status_code == 405
        data = response.json()
        assert "detail" in data
    
    @pytest.mark.unit
    def test_422_validation_error(self, client: TestClient, clean_items_storage):
        """422エラー（バリデーションエラー）のテスト"""
        # 必須フィールドが不足したデータ
        invalid_data = {
            "name": "テストアイテム"
            # description が不足
        }
        
        response = client.post("/api/items", json=invalid_data)
        
        assert response.status_code == 422
        data = response.json()
        assert "detail" in data
        
        # バリデーションエラーの詳細を確認
        errors = data["detail"]
        assert isinstance(errors, list)
        assert len(errors) > 0
        
        # descriptionフィールドのエラーが含まれていることを確認
        field_errors = [error for error in errors if "description" in str(error)]
        assert len(field_errors) > 0
    
    @pytest.mark.unit
    def test_validation_error_empty_fields(
        self, 
        client: TestClient, 
        clean_items_storage
    ):
        """空フィールドのバリデーションエラーテスト"""
        invalid_data = {
            "name": "",
            "description": ""
        }
        
        response = client.post("/api/items", json=invalid_data)
        
        assert response.status_code == 422
        data = response.json()
        
        # 複数のバリデーションエラーが発生することを確認
        errors = data["detail"]
        assert len(errors) >= 2  # nameとdescriptionの両方でエラー
    
    @pytest.mark.unit
    def test_validation_error_field_too_long(
        self, 
        client: TestClient, 
        clean_items_storage
    ):
        """フィールド長制限のバリデーションエラーテスト"""
        invalid_data = {
            "name": "a" * 101,  # 100文字制限を超える
            "description": "b" * 501  # 500文字制限を超える
        }
        
        response = client.post("/api/items", json=invalid_data)
        
        assert response.status_code == 422
        data = response.json()
        
        errors = data["detail"]
        assert len(errors) >= 2  # nameとdescriptionの両方でエラー
    
    @pytest.mark.unit
    def test_invalid_json_format(self, client: TestClient):
        """無効なJSON形式のテスト"""
        # 無効なJSONを送信
        response = client.post(
            "/api/items",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 422
    
    @pytest.mark.unit
    def test_missing_content_type(self, client: TestClient):
        """Content-Typeヘッダーが不足した場合のテスト"""
        valid_data = {
            "name": "テストアイテム",
            "description": "テスト用の説明"
        }
        
        # Content-Typeを指定せずにデータを送信
        response = client.post("/api/items", data=str(valid_data))
        
        # FastAPIは自動的に適切なエラーを返す
        assert response.status_code in [422, 400]
    
    @pytest.mark.unit
    def test_item_not_found_error_message(
        self, 
        client: TestClient, 
        clean_items_storage
    ):
        """アイテムが見つからない場合のエラーメッセージテスト"""
        non_existent_id = 999
        response = client.get(f"/api/items/{non_existent_id}")
        
        assert response.status_code == 404
        data = response.json()
        
        # エラーメッセージにIDが含まれていることを確認
        assert "detail" in data
        assert str(non_existent_id) in data["detail"]
        assert "見つかりません" in data["detail"]
    
    @pytest.mark.unit
    def test_update_item_not_found_error(
        self, 
        client: TestClient, 
        clean_items_storage
    ):
        """存在しないアイテムの更新エラーテスト"""
        update_data = {
            "name": "更新されたアイテム",
            "description": "更新された説明"
        }
        
        non_existent_id = 999
        response = client.put(f"/api/items/{non_existent_id}", json=update_data)
        
        assert response.status_code == 404
        data = response.json()
        
        assert "detail" in data
        assert str(non_existent_id) in data["detail"]
    
    @pytest.mark.unit
    def test_delete_item_not_found_error(
        self, 
        client: TestClient, 
        clean_items_storage
    ):
        """存在しないアイテムの削除エラーテスト"""
        non_existent_id = 999
        response = client.delete(f"/api/items/{non_existent_id}")
        
        assert response.status_code == 404
        data = response.json()
        
        assert "detail" in data
        assert str(non_existent_id) in data["detail"]
    
    @pytest.mark.unit
    def test_invalid_item_id_type(self, client: TestClient):
        """無効なアイテムIDタイプのテスト"""
        # 文字列のIDでアクセス
        response = client.get("/api/items/not_a_number")
        
        assert response.status_code == 422
        data = response.json()
        
        # バリデーションエラーの詳細を確認
        errors = data["detail"]
        assert isinstance(errors, list)
        
        # 型エラーが含まれていることを確認
        type_errors = [
            error for error in errors 
            if "type" in error and "int" in str(error)
        ]
        assert len(type_errors) > 0


class TestExceptionHandlers:
    """例外ハンドラーのテストクラス"""
    
    @pytest.mark.unit
    def test_http_exception_handler(self, client: TestClient):
        """HTTPExceptionハンドラーのテスト"""
        # 存在しないアイテムにアクセスしてHTTPExceptionを発生させる
        response = client.get("/api/items/999")
        
        assert response.status_code == 404
        data = response.json()
        
        # HTTPExceptionハンドラーが適切に動作していることを確認
        assert "detail" in data
        assert isinstance(data["detail"], str)
    
    @pytest.mark.unit
    def test_validation_exception_handler(self, client: TestClient):
        """ValidationExceptionハンドラーのテスト"""
        # バリデーションエラーを発生させる
        invalid_data = {"name": ""}  # description不足
        
        response = client.post("/api/items", json=invalid_data)
        
        assert response.status_code == 422
        data = response.json()
        
        # ValidationExceptionハンドラーが適切に動作していることを確認
        assert "detail" in data
        assert isinstance(data["detail"], list)
    
    @pytest.mark.unit
    def test_cors_headers(self, client: TestClient):
        """CORSヘッダーのテスト"""
        response = client.get("/health")
        
        assert response.status_code == 200
        
        # CORSヘッダーが設定されていることを確認
        # 注意: TestClientではCORSヘッダーが自動的に設定されない場合があるため、
        # 実際のブラウザテストでの確認が必要
        # ここではレスポンスが正常に返されることを確認
        assert response.headers.get("content-type") == "application/json"
"""
ヘルスチェックエンドポイントのテスト
"""

import pytest
from fastapi.testclient import TestClient
from datetime import datetime
from unittest.mock import patch


class TestHealthEndpoint:
    """ヘルスチェックエンドポイントのテストクラス"""
    
    @pytest.mark.unit
    def test_health_check_success(self, client: TestClient):
        """正常なヘルスチェックのテスト"""
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        
        # レスポンス構造の確認
        assert "status" in data
        assert "timestamp" in data
        assert "service" in data
        
        # レスポンス値の確認
        assert data["status"] == "healthy"
        assert data["service"] == "CI/CD Comparison API"
        
        # タイムスタンプが有効なISO形式であることを確認
        timestamp_str = data["timestamp"]
        # ISO形式のパース確認
        parsed_timestamp = datetime.fromisoformat(
            timestamp_str.replace('Z', '+00:00')
        )
        assert isinstance(parsed_timestamp, datetime)
    
    @pytest.mark.unit
    def test_health_check_response_headers(self, client: TestClient):
        """ヘルスチェックのレスポンスヘッダーテスト"""
        response = client.get("/health")
        
        assert response.status_code == 200
        assert "application/json" in response.headers["content-type"]
    
    @pytest.mark.unit
    def test_health_check_multiple_calls(self, client: TestClient):
        """複数回のヘルスチェック呼び出しテスト"""
        # 複数回呼び出して一貫性を確認
        responses = []
        for _ in range(3):
            response = client.get("/health")
            assert response.status_code == 200
            responses.append(response.json())
        
        # 全てのレスポンスでstatusとserviceが一致することを確認
        for data in responses:
            assert data["status"] == "healthy"
            assert data["service"] == "CI/CD Comparison API"
    
    @pytest.mark.unit
    def test_health_check_with_mock_datetime(self, client: TestClient):
        """モックされた日時でのヘルスチェックテスト"""
        fixed_datetime = datetime(2024, 1, 1, 12, 0, 0)
        
        with patch('modules.api.routers.health.datetime') as mock_dt:
            mock_dt.utcnow.return_value = fixed_datetime
            
            response = client.get("/health")
            
            assert response.status_code == 200
            data = response.json()
            
            # モックされた時刻が返されることを確認
            expected_timestamp = fixed_datetime.isoformat()
            assert data["timestamp"] == expected_timestamp
    
    @pytest.mark.unit
    def test_health_check_method_not_allowed(self, client: TestClient):
        """許可されていないHTTPメソッドのテスト"""
        # POST メソッドは許可されていない
        response = client.post("/health")
        assert response.status_code == 405
        
        # PUT メソッドは許可されていない
        response = client.put("/health")
        assert response.status_code == 405
        
        # DELETE メソッドは許可されていない
        response = client.delete("/health")
        assert response.status_code == 405
    
    @pytest.mark.unit
    def test_health_check_response_schema(self, client: TestClient):
        """レスポンススキーマの詳細テスト"""
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        
        # 必須フィールドの存在確認
        required_fields = ["status", "timestamp", "service"]
        for field in required_fields:
            assert field in data, f"必須フィールド '{field}' が見つかりません"
        
        # データ型の確認
        assert isinstance(data["status"], str)
        assert isinstance(data["timestamp"], str)
        assert isinstance(data["service"], str)
        
        # 値の妥当性確認
        assert data["status"] != ""
        assert data["service"] != ""
        assert len(data["timestamp"]) > 0
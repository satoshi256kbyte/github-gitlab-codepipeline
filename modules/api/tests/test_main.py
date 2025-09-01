"""
メインアプリケーションのテスト
"""

import pytest
from fastapi.testclient import TestClient
from datetime import datetime


class TestMainApplication:
    """メインアプリケーションのテストクラス"""
    
    def test_root_endpoint(self, client: TestClient):
        """ルートエンドポイントのテスト"""
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        
        assert "message" in data
        assert "version" in data
        assert "environment" in data
        assert "timestamp" in data
        assert data["message"] == "Welcome to CI/CD Comparison API"
        assert data["version"] == "1.0.0"
        assert data["environment"] == "local"
        
        # タイムスタンプが有効なISO形式であることを確認
        timestamp = datetime.fromisoformat(data["timestamp"].replace('Z', '+00:00'))
        assert isinstance(timestamp, datetime)
    
    def test_docs_endpoint(self, client: TestClient):
        """API ドキュメントエンドポイントのテスト"""
        response = client.get("/docs")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
    
    def test_redoc_endpoint(self, client: TestClient):
        """ReDoc エンドポイントのテスト"""
        response = client.get("/redoc")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
    
    def test_openapi_schema(self, client: TestClient):
        """OpenAPI スキーマのテスト"""
        response = client.get("/openapi.json")
        assert response.status_code == 200
        
        schema = response.json()
        assert "openapi" in schema
        assert "info" in schema
        assert schema["info"]["title"] == "CI/CD Comparison API"
        assert schema["info"]["version"] == "1.0.0"
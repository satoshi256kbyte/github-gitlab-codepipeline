"""
バージョン情報エンドポイントのテスト
"""

from datetime import datetime
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


class TestVersionEndpoint:
    """バージョン情報エンドポイントのテストクラス"""

    @pytest.mark.unit
    def test_version_info_success(self, client: TestClient):
        """正常なバージョン情報取得のテスト"""
        response = client.get("/version")

        assert response.status_code == 200
        data = response.json()

        # レスポンス構造の確認
        assert "version" in data
        assert "build_time" in data
        assert "commit_hash" in data
        assert "environment" in data

        # デフォルト値の確認
        assert data["version"] == "1.0.0"
        assert isinstance(data["build_time"], str)
        assert isinstance(data["commit_hash"], str)
        assert isinstance(data["environment"], str)

    @pytest.mark.unit
    def test_version_info_with_environment_variables(
        self, client: TestClient, mock_environment_variables
    ):
        """環境変数が設定された場合のバージョン情報テスト"""
        response = client.get("/version")

        assert response.status_code == 200
        data = response.json()

        # 環境変数から取得した値の確認
        assert data["commit_hash"] == "abc123def456"
        assert data["environment"] == "test"

    @pytest.mark.unit
    def test_version_info_without_environment_variables(self, client: TestClient):
        """環境変数が設定されていない場合のテスト"""
        # 環境変数をクリア
        with patch.dict("os.environ", {}, clear=True):
            response = client.get("/version")

            assert response.status_code == 200
            data = response.json()

            # デフォルト値の確認
            assert data["commit_hash"] == "unknown"
            assert data["environment"] == "local"

    @pytest.mark.unit
    def test_version_info_build_time_format(self, client: TestClient):
        """build_timeの形式テスト"""
        response = client.get("/version")

        assert response.status_code == 200
        data = response.json()

        # ISO形式の日時文字列であることを確認
        build_time_str = data["build_time"]
        parsed_time = datetime.fromisoformat(build_time_str.replace("Z", "+00:00"))
        assert isinstance(parsed_time, datetime)

    @pytest.mark.unit
    def test_version_info_response_headers(self, client: TestClient):
        """バージョン情報のレスポンスヘッダーテスト"""
        response = client.get("/version")

        assert response.status_code == 200
        assert "application/json" in response.headers["content-type"]

    @pytest.mark.unit
    def test_version_info_method_not_allowed(self, client: TestClient):
        """許可されていないHTTPメソッドのテスト"""
        # POST メソッドは許可されていない
        response = client.post("/version")
        assert response.status_code == 405

        # PUT メソッドは許可されていない
        response = client.put("/version")
        assert response.status_code == 405

        # DELETE メソッドは許可されていない
        response = client.delete("/version")
        assert response.status_code == 405

    @pytest.mark.unit
    def test_version_info_multiple_calls_consistency(self, client: TestClient):
        """複数回呼び出しでの一貫性テスト"""
        responses = []
        for _ in range(3):
            response = client.get("/version")
            assert response.status_code == 200
            responses.append(response.json())

        # version は常に同じ値であることを確認
        versions = [data["version"] for data in responses]
        assert all(v == "1.0.0" for v in versions)

    @pytest.mark.unit
    def test_version_info_with_custom_commit_hash(self, client: TestClient):
        """カスタムコミットハッシュでのテスト"""
        custom_hash = "custom123hash456"
        custom_env = "production"

        with patch.dict(
            "os.environ", {"COMMIT_HASH": custom_hash, "APP_ENVIRONMENT": custom_env}
        ):
            response = client.get("/version")

            assert response.status_code == 200
            data = response.json()

            assert data["commit_hash"] == custom_hash
            assert data["environment"] == custom_env

    @pytest.mark.unit
    def test_version_info_response_schema(self, client: TestClient):
        """レスポンススキーマの詳細テスト"""
        response = client.get("/version")

        assert response.status_code == 200
        data = response.json()

        # 必須フィールドの存在確認
        required_fields = ["version", "build_time", "commit_hash", "environment"]
        for field in required_fields:
            assert field in data, f"必須フィールド '{field}' が見つかりません"

        # データ型の確認
        assert isinstance(data["version"], str)
        assert isinstance(data["build_time"], str)
        assert isinstance(data["commit_hash"], str)
        assert isinstance(data["environment"], str)

        # 値の妥当性確認
        assert data["version"] != ""
        assert data["build_time"] != ""
        assert data["commit_hash"] != ""
        assert data["environment"] != ""

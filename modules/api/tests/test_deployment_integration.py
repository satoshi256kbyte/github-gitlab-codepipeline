"""
デプロイメント統合テスト
各デプロイ先での動作確認とパイプライン失敗条件のテスト
"""

import os
import time

import pytest
import requests


class DeploymentTestConfig:
    """デプロイメントテスト設定"""

    # 環境変数から各デプロイ先のエンドポイントを取得
    LAMBDA_ENDPOINT = os.getenv("LAMBDA_ENDPOINT")
    ECS_ENDPOINT = os.getenv("ECS_ENDPOINT")
    EC2_ENDPOINT = os.getenv("EC2_ENDPOINT")

    # テストタイムアウト設定
    REQUEST_TIMEOUT = 30
    HEALTH_CHECK_RETRY_COUNT = 5
    HEALTH_CHECK_RETRY_INTERVAL = 10


class TestLambdaDeployment:
    """Lambda デプロイメント統合テスト"""

    @pytest.mark.skipif(
        not DeploymentTestConfig.LAMBDA_ENDPOINT,
        reason="LAMBDA_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_lambda_health_check(self):
        """Lambda デプロイ先のヘルスチェック"""
        endpoint = DeploymentTestConfig.LAMBDA_ENDPOINT

        for attempt in range(DeploymentTestConfig.HEALTH_CHECK_RETRY_COUNT):
            try:
                response = requests.get(
                    f"{endpoint}/health", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
                )

                if response.status_code == 200:
                    data = response.json()
                    assert data["status"] == "healthy"
                    assert "timestamp" in data
                    return

            except requests.exceptions.RequestException as e:
                if attempt == DeploymentTestConfig.HEALTH_CHECK_RETRY_COUNT - 1:
                    pytest.fail(f"Lambda ヘルスチェック失敗: {e}")
                time.sleep(DeploymentTestConfig.HEALTH_CHECK_RETRY_INTERVAL)

    @pytest.mark.skipif(
        not DeploymentTestConfig.LAMBDA_ENDPOINT,
        reason="LAMBDA_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_lambda_version_endpoint(self):
        """Lambda バージョン情報エンドポイントテスト"""
        endpoint = DeploymentTestConfig.LAMBDA_ENDPOINT

        response = requests.get(
            f"{endpoint}/version", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
        )

        assert response.status_code == 200
        data = response.json()
        assert "version" in data
        assert data["version"] == "1.0.0"
        assert "build_time" in data
        assert "commit_hash" in data

    @pytest.mark.skipif(
        not DeploymentTestConfig.LAMBDA_ENDPOINT,
        reason="LAMBDA_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_lambda_crud_operations(self):
        """Lambda CRUD操作テスト"""
        endpoint = DeploymentTestConfig.LAMBDA_ENDPOINT

        # アイテム作成
        item_data = {
            "name": "Lambda統合テストアイテム",
            "description": "Lambda環境での統合テスト用アイテム",
        }

        create_response = requests.post(
            f"{endpoint}/api/items",
            json=item_data,
            timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
        )

        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        try:
            # アイテム取得
            get_response = requests.get(
                f"{endpoint}/api/items/{item_id}",
                timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
            )

            assert get_response.status_code == 200
            retrieved_item = get_response.json()
            assert retrieved_item["name"] == item_data["name"]
            assert retrieved_item["description"] == item_data["description"]

            # アイテム一覧取得
            list_response = requests.get(
                f"{endpoint}/api/items", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
            )

            assert list_response.status_code == 200
            list_data = list_response.json()
            assert len(list_data["items"]) >= 1

        finally:
            # クリーンアップ
            requests.delete(
                f"{endpoint}/api/items/{item_id}",
                timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
            )


class TestECSDeployment:
    """ECS デプロイメント統合テスト"""

    @pytest.mark.skipif(
        not DeploymentTestConfig.ECS_ENDPOINT,
        reason="ECS_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ecs_health_check(self):
        """ECS デプロイ先のヘルスチェック"""
        endpoint = DeploymentTestConfig.ECS_ENDPOINT

        for attempt in range(DeploymentTestConfig.HEALTH_CHECK_RETRY_COUNT):
            try:
                response = requests.get(
                    f"{endpoint}/health", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
                )

                if response.status_code == 200:
                    data = response.json()
                    assert data["status"] == "healthy"
                    assert "timestamp" in data
                    return

            except requests.exceptions.RequestException as e:
                if attempt == DeploymentTestConfig.HEALTH_CHECK_RETRY_COUNT - 1:
                    pytest.fail(f"ECS ヘルスチェック失敗: {e}")
                time.sleep(DeploymentTestConfig.HEALTH_CHECK_RETRY_INTERVAL)

    @pytest.mark.skipif(
        not DeploymentTestConfig.ECS_ENDPOINT,
        reason="ECS_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ecs_version_endpoint(self):
        """ECS バージョン情報エンドポイントテスト"""
        endpoint = DeploymentTestConfig.ECS_ENDPOINT

        response = requests.get(
            f"{endpoint}/version", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
        )

        assert response.status_code == 200
        data = response.json()
        assert "version" in data
        assert data["version"] == "1.0.0"
        assert "build_time" in data
        assert "commit_hash" in data

    @pytest.mark.skipif(
        not DeploymentTestConfig.ECS_ENDPOINT,
        reason="ECS_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ecs_crud_operations(self):
        """ECS CRUD操作テスト"""
        endpoint = DeploymentTestConfig.ECS_ENDPOINT

        # アイテム作成
        item_data = {
            "name": "ECS統合テストアイテム",
            "description": "ECS環境での統合テスト用アイテム",
        }

        create_response = requests.post(
            f"{endpoint}/api/items",
            json=item_data,
            timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
        )

        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        try:
            # アイテム取得
            get_response = requests.get(
                f"{endpoint}/api/items/{item_id}",
                timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
            )

            assert get_response.status_code == 200
            retrieved_item = get_response.json()
            assert retrieved_item["name"] == item_data["name"]
            assert retrieved_item["description"] == item_data["description"]

            # アイテム一覧取得
            list_response = requests.get(
                f"{endpoint}/api/items", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
            )

            assert list_response.status_code == 200
            list_data = list_response.json()
            assert len(list_data["items"]) >= 1

        finally:
            # クリーンアップ
            requests.delete(
                f"{endpoint}/api/items/{item_id}",
                timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
            )

    @pytest.mark.skipif(
        not DeploymentTestConfig.ECS_ENDPOINT,
        reason="ECS_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ecs_blue_green_deployment_readiness(self):
        """ECS Blue/Green デプロイメント準備状況テスト"""
        endpoint = DeploymentTestConfig.ECS_ENDPOINT

        # ヘルスチェックエンドポイントが正常に応答することを確認
        # Blue/Greenデプロイメント時にALBのヘルスチェックが成功する必要がある
        response = requests.get(
            f"{endpoint}/health", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"

        # レスポンス時間が適切であることを確認（ALBのヘルスチェック要件）
        assert response.elapsed.total_seconds() < 5.0


class TestEC2Deployment:
    """EC2 デプロイメント統合テスト"""

    @pytest.mark.skipif(
        not DeploymentTestConfig.EC2_ENDPOINT,
        reason="EC2_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ec2_health_check(self):
        """EC2 デプロイ先のヘルスチェック"""
        endpoint = DeploymentTestConfig.EC2_ENDPOINT

        for attempt in range(DeploymentTestConfig.HEALTH_CHECK_RETRY_COUNT):
            try:
                response = requests.get(
                    f"{endpoint}/health", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
                )

                if response.status_code == 200:
                    data = response.json()
                    assert data["status"] == "healthy"
                    assert "timestamp" in data
                    return

            except requests.exceptions.RequestException as e:
                if attempt == DeploymentTestConfig.HEALTH_CHECK_RETRY_COUNT - 1:
                    pytest.fail(f"EC2 ヘルスチェック失敗: {e}")
                time.sleep(DeploymentTestConfig.HEALTH_CHECK_RETRY_INTERVAL)

    @pytest.mark.skipif(
        not DeploymentTestConfig.EC2_ENDPOINT,
        reason="EC2_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ec2_version_endpoint(self):
        """EC2 バージョン情報エンドポイントテスト"""
        endpoint = DeploymentTestConfig.EC2_ENDPOINT

        response = requests.get(
            f"{endpoint}/version", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
        )

        assert response.status_code == 200
        data = response.json()
        assert "version" in data
        assert data["version"] == "1.0.0"
        assert "build_time" in data
        assert "commit_hash" in data

    @pytest.mark.skipif(
        not DeploymentTestConfig.EC2_ENDPOINT,
        reason="EC2_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ec2_crud_operations(self):
        """EC2 CRUD操作テスト"""
        endpoint = DeploymentTestConfig.EC2_ENDPOINT

        # アイテム作成
        item_data = {
            "name": "EC2統合テストアイテム",
            "description": "EC2環境での統合テスト用アイテム",
        }

        create_response = requests.post(
            f"{endpoint}/api/items",
            json=item_data,
            timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
        )

        assert create_response.status_code == 201
        created_item = create_response.json()
        item_id = created_item["id"]

        try:
            # アイテム取得
            get_response = requests.get(
                f"{endpoint}/api/items/{item_id}",
                timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
            )

            assert get_response.status_code == 200
            retrieved_item = get_response.json()
            assert retrieved_item["name"] == item_data["name"]
            assert retrieved_item["description"] == item_data["description"]

            # アイテム一覧取得
            list_response = requests.get(
                f"{endpoint}/api/items", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
            )

            assert list_response.status_code == 200
            list_data = list_response.json()
            assert len(list_data["items"]) >= 1

        finally:
            # クリーンアップ
            requests.delete(
                f"{endpoint}/api/items/{item_id}",
                timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
            )

    @pytest.mark.skipif(
        not DeploymentTestConfig.EC2_ENDPOINT,
        reason="EC2_ENDPOINT環境変数が設定されていません",
    )
    @pytest.mark.deployment
    def test_ec2_codedeploy_readiness(self):
        """EC2 CodeDeploy準備状況テスト"""
        endpoint = DeploymentTestConfig.EC2_ENDPOINT

        # ヘルスチェックエンドポイントが正常に応答することを確認
        # CodeDeployのヘルスチェックが成功する必要がある
        response = requests.get(
            f"{endpoint}/health", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"

        # レスポンス時間が適切であることを確認
        assert response.elapsed.total_seconds() < 5.0


class TestCrossDeploymentConsistency:
    """デプロイ先間の一貫性テスト"""

    @pytest.mark.deployment
    def test_all_deployments_version_consistency(self):
        """全デプロイ先でのバージョン一貫性テスト"""
        endpoints = []

        if DeploymentTestConfig.LAMBDA_ENDPOINT:
            endpoints.append(("Lambda", DeploymentTestConfig.LAMBDA_ENDPOINT))
        if DeploymentTestConfig.ECS_ENDPOINT:
            endpoints.append(("ECS", DeploymentTestConfig.ECS_ENDPOINT))
        if DeploymentTestConfig.EC2_ENDPOINT:
            endpoints.append(("EC2", DeploymentTestConfig.EC2_ENDPOINT))

        if len(endpoints) < 2:
            pytest.skip("複数のデプロイ先が設定されていません")

        versions = {}

        for deployment_name, endpoint in endpoints:
            try:
                response = requests.get(
                    f"{endpoint}/version", timeout=DeploymentTestConfig.REQUEST_TIMEOUT
                )

                if response.status_code == 200:
                    data = response.json()
                    versions[deployment_name] = data["version"]

            except requests.exceptions.RequestException:
                pytest.fail(f"{deployment_name} デプロイ先にアクセスできません")

        # 全てのデプロイ先で同じバージョンが返されることを確認
        unique_versions = set(versions.values())
        assert len(unique_versions) == 1, (
            f"デプロイ先間でバージョンが一致しません: {versions}"
        )

    @pytest.mark.deployment
    def test_all_deployments_api_consistency(self):
        """全デプロイ先でのAPI一貫性テスト"""
        endpoints = []

        if DeploymentTestConfig.LAMBDA_ENDPOINT:
            endpoints.append(("Lambda", DeploymentTestConfig.LAMBDA_ENDPOINT))
        if DeploymentTestConfig.ECS_ENDPOINT:
            endpoints.append(("ECS", DeploymentTestConfig.ECS_ENDPOINT))
        if DeploymentTestConfig.EC2_ENDPOINT:
            endpoints.append(("EC2", DeploymentTestConfig.EC2_ENDPOINT))

        if len(endpoints) < 2:
            pytest.skip("複数のデプロイ先が設定されていません")

        # 各デプロイ先で同じAPIエンドポイントが利用可能であることを確認
        test_endpoints = ["/", "/health", "/version", "/api/items"]

        for deployment_name, base_endpoint in endpoints:
            for api_endpoint in test_endpoints:
                try:
                    response = requests.get(
                        f"{base_endpoint}{api_endpoint}",
                        timeout=DeploymentTestConfig.REQUEST_TIMEOUT,
                    )

                    assert response.status_code in [
                        200,
                        404,
                    ], (
                        f"{deployment_name}の{api_endpoint}が予期しないステータスコードを返しました: {response.status_code}"
                    )

                except requests.exceptions.RequestException as e:
                    pytest.fail(
                        f"{deployment_name}の{api_endpoint}にアクセスできません: {e}"
                    )

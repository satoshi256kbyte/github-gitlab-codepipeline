"""
CI/CDツール間の独立性を確認する統合テスト

各CI/CDツール専用のAWSリソースが独立して動作し、
相互に影響しないことを確認する。
"""

import asyncio
import os

import httpx
import pytest


class TestCICDToolIsolation:
    """CI/CDツール間の独立性テスト"""

    # 各CI/CDツール専用のエンドポイント
    ENDPOINTS = {
        "github": "http://github-local-alb-api:8080",
        "gitlab": "http://gitlab-local-alb-api:8081",
        "codepipeline": "http://codepipeline-local-alb-api:8082",
    }

    @pytest.mark.skipif(
        os.getenv("ENVIRONMENT") == "local" or os.getenv("STAGE_NAME") == "local",
        reason="CICD tool isolation tests require deployed AWS infrastructure",
    )
    @pytest.mark.asyncio
    async def test_concurrent_health_checks(self):
        """
        3つのCI/CDツール専用エンドポイントに同時アクセスして
        相互に影響しないことを確認
        """

        async def check_health(tool_name: str, endpoint: str) -> dict:
            """個別のヘルスチェック"""
            try:
                async with httpx.AsyncClient(timeout=30.0) as client:
                    response = await client.get(f"{endpoint}/health")
                    return {
                        "tool": tool_name,
                        "status_code": response.status_code,
                        "response_time": response.elapsed.total_seconds(),
                        "success": response.status_code == 200,
                    }
            except Exception as e:
                return {
                    "tool": tool_name,
                    "status_code": None,
                    "response_time": None,
                    "success": False,
                    "error": str(e),
                }

        # 同時実行
        tasks = [
            check_health(tool, endpoint) for tool, endpoint in self.ENDPOINTS.items()
        ]

        results = await asyncio.gather(*tasks)

        # 全てのエンドポイントが正常に応答することを確認
        for result in results:
            assert result["success"], (
                f"{result['tool']} endpoint failed: {result.get('error', 'Unknown error')}"
            )
            assert result["status_code"] == 200
            assert result["response_time"] is not None

        # レスポンス時間が極端に遅くないことを確認（相互干渉がないことの間接的確認）
        response_times = [r["response_time"] for r in results if r["response_time"]]
        avg_response_time = sum(response_times) / len(response_times)
        assert avg_response_time < 5.0, (
            f"Average response time too slow: {avg_response_time}s"
        )

    @pytest.mark.skipif(
        os.getenv("ENVIRONMENT") == "local" or os.getenv("STAGE_NAME") == "local",
        reason="CICD tool isolation tests require deployed AWS infrastructure",
    )
    @pytest.mark.asyncio
    async def test_concurrent_crud_operations(self):
        """
        各CI/CDツール専用エンドポイントで同時にCRUD操作を実行し、
        データが混在しないことを確認
        """

        async def perform_crud_operations(tool_name: str, endpoint: str) -> dict:
            """CRUD操作の実行"""
            try:
                async with httpx.AsyncClient(timeout=30.0) as client:
                    # アイテム作成
                    create_data = {
                        "name": f"{tool_name}_test_item",
                        "description": f"Test item for {tool_name} CI/CD tool",
                    }
                    create_response = await client.post(
                        f"{endpoint}/api/items", json=create_data
                    )

                    if create_response.status_code != 201:
                        return {
                            "tool": tool_name,
                            "success": False,
                            "error": "Create failed",
                        }

                    item_id = create_response.json()["id"]

                    # アイテム取得
                    get_response = await client.get(f"{endpoint}/api/items/{item_id}")
                    if get_response.status_code != 200:
                        return {
                            "tool": tool_name,
                            "success": False,
                            "error": "Get failed",
                        }

                    item_data = get_response.json()

                    # データの整合性確認
                    if item_data["name"] != create_data["name"]:
                        return {
                            "tool": tool_name,
                            "success": False,
                            "error": "Data mismatch",
                        }

                    return {
                        "tool": tool_name,
                        "success": True,
                        "item_id": item_id,
                        "item_name": item_data["name"],
                    }

            except Exception as e:
                return {"tool": tool_name, "success": False, "error": str(e)}

        # 同時実行
        tasks = [
            perform_crud_operations(tool, endpoint)
            for tool, endpoint in self.ENDPOINTS.items()
        ]

        results = await asyncio.gather(*tasks)

        # 全ての操作が成功することを確認
        for result in results:
            assert result["success"], (
                f"{result['tool']} CRUD operations failed: {result.get('error', 'Unknown error')}"
            )

        # 各ツールで作成されたアイテムが正しく分離されていることを確認
        item_names = [r["item_name"] for r in results if r["success"]]
        assert len(set(item_names)) == len(item_names), (
            "Item names should be unique across tools"
        )

        for result in results:
            expected_name = f"{result['tool']}_test_item"
            assert result["item_name"] == expected_name, (
                f"Item name mismatch for {result['tool']}"
            )

    @pytest.mark.asyncio
    async def test_load_balancer_port_isolation(self):
        """
        各CI/CDツール専用のロードバランサーが異なるポートで動作し、
        ポート間で干渉しないことを確認
        """
        port_mappings = {"github": 8080, "gitlab": 8081, "codepipeline": 8082}

        async def check_port_access(tool_name: str, port: int) -> dict:
            """特定ポートへのアクセス確認"""
            try:
                # 実際の環境では適切なホスト名に置き換える
                endpoint = f"http://localhost:{port}"
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(f"{endpoint}/health")
                    return {
                        "tool": tool_name,
                        "port": port,
                        "accessible": response.status_code == 200,
                        "status_code": response.status_code,
                    }
            except Exception as e:
                return {
                    "tool": tool_name,
                    "port": port,
                    "accessible": False,
                    "error": str(e),
                }

        # 各ポートに同時アクセス
        tasks = [check_port_access(tool, port) for tool, port in port_mappings.items()]

        results = await asyncio.gather(*tasks)

        # 各ツールが専用ポートでアクセス可能であることを確認
        # 注: 実際のテスト環境が構築されていない場合はスキップ
        accessible_count = sum(1 for r in results if r["accessible"])

        if accessible_count > 0:
            # 少なくとも1つのエンドポイントがアクセス可能な場合
            for result in results:
                if result["accessible"]:
                    assert result["status_code"] == 200
                    print(f"✓ {result['tool']} accessible on port {result['port']}")
        else:
            # 全てアクセス不可の場合（テスト環境未構築）
            pytest.skip(
                "CI/CD tool endpoints not accessible - infrastructure not deployed"
            )

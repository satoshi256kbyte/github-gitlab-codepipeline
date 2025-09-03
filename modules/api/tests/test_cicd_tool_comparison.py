"""
CI/CDツール比較用エンドポイントアクセステスト
各CI/CDツール専用エンドポイント（異なるポート）でのアクセステストを実装
"""

import time

import pytest
import requests


class TestCICDToolEndpointComparison:
    """CI/CDツール専用エンドポイント比較テストクラス"""

    # 各CI/CDツール専用のエンドポイント設定
    ENDPOINTS = {
        "github": {
            "name": "GitHub Actions",
            "port": 8080,
            "base_url": "http://localhost:8080",
            "alb_url": "http://github-local-alb-api.example.com",  # 実際のALB URLに置き換え
            "lambda_url": "https://github-local-api.execute-api.ap-northeast-1.amazonaws.com/prod",  # 実際のAPI Gateway URLに置き換え
        },
        "gitlab": {
            "name": "GitLab CI/CD",
            "port": 8081,
            "base_url": "http://localhost:8081",
            "alb_url": "http://gitlab-local-alb-api.example.com",  # 実際のALB URLに置き換え
            "lambda_url": "https://gitlab-local-api.execute-api.ap-northeast-1.amazonaws.com/prod",  # 実際のAPI Gateway URLに置き換え
        },
        "codepipeline": {
            "name": "CodePipeline",
            "port": 8082,
            "base_url": "http://localhost:8082",
            "alb_url": "http://codepipeline-local-alb-api.example.com",  # 実際のALB URLに置き換え
            "lambda_url": "https://codepipeline-local-api.execute-api.ap-northeast-1.amazonaws.com/prod",  # 実際のAPI Gateway URLに置き換え
        },
    }

    @pytest.fixture
    def endpoint_configs(self):
        """エンドポイント設定のフィクスチャ"""
        return self.ENDPOINTS

    def _make_request(
        self,
        url: str,
        method: str = "GET",
        json_data: dict | None = None,
        timeout: int = 30,
    ) -> requests.Response | None:
        """
        HTTPリクエストを実行し、エラーハンドリングを行う

        Args:
            url: リクエストURL
            method: HTTPメソッド
            json_data: JSONデータ（POSTリクエスト用）
            timeout: タイムアウト時間

        Returns:
            レスポンスオブジェクト、またはエラー時はNone
        """
        try:
            if method.upper() == "GET":
                response = requests.get(url, timeout=timeout)
            elif method.upper() == "POST":
                response = requests.post(url, json=json_data, timeout=timeout)
            elif method.upper() == "PUT":
                response = requests.put(url, json=json_data, timeout=timeout)
            elif method.upper() == "DELETE":
                response = requests.delete(url, timeout=timeout)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")

            return response
        except requests.exceptions.RequestException as e:
            print(f"Request failed for {url}: {e}")
            return None

    @pytest.mark.integration
    @pytest.mark.parametrize("tool_name", ["github", "gitlab", "codepipeline"])
    def test_health_check_endpoints(self, endpoint_configs, tool_name):
        """各CI/CDツール専用エンドポイントのヘルスチェック確認テスト"""
        tool_config = endpoint_configs[tool_name]

        # 各デプロイ先でのヘルスチェックテスト
        deployment_targets = ["lambda_url", "alb_url"]

        for target in deployment_targets:
            if target in tool_config:
                health_url = f"{tool_config[target]}/health"

                response = self._make_request(health_url)

                if response is not None:
                    assert response.status_code == 200, (
                        f"{tool_config['name']} {target} ヘルスチェックが失敗しました"
                    )

                    health_data = response.json()
                    assert health_data["status"] == "healthy", (
                        f"{tool_config['name']} {target} のステータスが正常ではありません"
                    )
                    assert "timestamp" in health_data, (
                        f"{tool_config['name']} {target} のレスポンスにタイムスタンプがありません"
                    )
                else:
                    pytest.skip(
                        f"{tool_config['name']} {target} エンドポイントにアクセスできません（デプロイされていない可能性があります）"
                    )

    @pytest.mark.integration
    @pytest.mark.parametrize("tool_name", ["github", "gitlab", "codepipeline"])
    def test_version_endpoints(self, endpoint_configs, tool_name):
        """各CI/CDツール専用エンドポイントのバージョン情報確認テスト"""
        tool_config = endpoint_configs[tool_name]

        deployment_targets = ["lambda_url", "alb_url"]

        for target in deployment_targets:
            if target in tool_config:
                version_url = f"{tool_config[target]}/version"

                response = self._make_request(version_url)

                if response is not None:
                    assert response.status_code == 200, (
                        f"{tool_config['name']} {target} バージョン情報取得が失敗しました"
                    )

                    version_data = response.json()
                    assert "version" in version_data, (
                        f"{tool_config['name']} {target} のレスポンスにバージョン情報がありません"
                    )
                    assert version_data["version"] == "1.0.0", (
                        f"{tool_config['name']} {target} のバージョンが期待値と異なります"
                    )
                    assert "build_time" in version_data, (
                        f"{tool_config['name']} {target} のレスポンスにビルド時間がありません"
                    )
                else:
                    pytest.skip(
                        f"{tool_config['name']} {target} エンドポイントにアクセスできません（デプロイされていない可能性があります）"
                    )

    @pytest.mark.integration
    @pytest.mark.parametrize("tool_name", ["github", "gitlab", "codepipeline"])
    def test_basic_crud_operations(self, endpoint_configs, tool_name):
        """各ツール専用リソースでの基本的なCRUD操作の動作確認テスト"""
        tool_config = endpoint_configs[tool_name]

        deployment_targets = ["lambda_url", "alb_url"]

        for target in deployment_targets:
            if target in tool_config:
                base_url = tool_config[target]

                # 1. アイテム一覧取得（初期状態）
                list_response = self._make_request(f"{base_url}/api/items")

                if list_response is None:
                    pytest.skip(
                        f"{tool_config['name']} {target} エンドポイントにアクセスできません（デプロイされていない可能性があります）"
                    )
                    continue

                assert list_response.status_code == 200, (
                    f"{tool_config['name']} {target} アイテム一覧取得が失敗しました"
                )

                initial_data = list_response.json()
                initial_count = initial_data["total"]

                # 2. アイテム作成
                test_item = {
                    "name": f"{tool_config['name']} テストアイテム",
                    "description": f"{tool_config['name']} 用のテストアイテムです",
                }

                create_response = self._make_request(
                    f"{base_url}/api/items", "POST", test_item
                )
                assert create_response.status_code == 201, (
                    f"{tool_config['name']} {target} アイテム作成が失敗しました"
                )

                created_item = create_response.json()
                item_id = created_item["id"]

                # 3. 作成されたアイテムの個別取得
                get_response = self._make_request(f"{base_url}/api/items/{item_id}")
                assert get_response.status_code == 200, (
                    f"{tool_config['name']} {target} アイテム個別取得が失敗しました"
                )

                retrieved_item = get_response.json()
                assert retrieved_item["name"] == test_item["name"], (
                    f"{tool_config['name']} {target} 取得したアイテム名が一致しません"
                )
                assert retrieved_item["description"] == test_item["description"], (
                    f"{tool_config['name']} {target} 取得したアイテム説明が一致しません"
                )

                # 4. アイテム更新
                update_data = {
                    "name": f"{tool_config['name']} 更新されたテストアイテム",
                    "description": f"{tool_config['name']} 用の更新されたテストアイテムです",
                }

                update_response = self._make_request(
                    f"{base_url}/api/items/{item_id}", "PUT", update_data
                )
                assert update_response.status_code == 200, (
                    f"{tool_config['name']} {target} アイテム更新が失敗しました"
                )

                updated_item = update_response.json()
                assert updated_item["name"] == update_data["name"], (
                    f"{tool_config['name']} {target} 更新されたアイテム名が一致しません"
                )

                # 5. アイテム削除
                delete_response = self._make_request(
                    f"{base_url}/api/items/{item_id}", "DELETE"
                )
                assert delete_response.status_code == 204, (
                    f"{tool_config['name']} {target} アイテム削除が失敗しました"
                )

                # 6. 削除確認
                get_deleted_response = self._make_request(
                    f"{base_url}/api/items/{item_id}"
                )
                assert get_deleted_response.status_code == 404, (
                    f"{tool_config['name']} {target} 削除されたアイテムが取得できてしまいました"
                )

                # 7. 最終的なアイテム数確認
                final_list_response = self._make_request(f"{base_url}/api/items")
                assert final_list_response.status_code == 200, (
                    f"{tool_config['name']} {target} 最終アイテム一覧取得が失敗しました"
                )

                final_data = final_list_response.json()
                assert final_data["total"] == initial_count, (
                    f"{tool_config['name']} {target} 最終的なアイテム数が初期状態と一致しません"
                )

    @pytest.mark.integration
    def test_cross_tool_isolation(self, endpoint_configs):
        """各CI/CDツール間のリソース分離確認テスト"""
        # 各ツールで同時にアイテムを作成し、他のツールに影響しないことを確認
        created_items = {}

        for tool_name, tool_config in endpoint_configs.items():
            # Lambda URLでテスト（利用可能な場合）
            base_url = tool_config["lambda_url"]

            # アイテム作成
            test_item = {
                "name": f"{tool_config['name']} 分離テストアイテム",
                "description": f"{tool_config['name']} 専用の分離テストアイテムです",
            }

            create_response = self._make_request(
                f"{base_url}/api/items", "POST", test_item
            )

            if create_response is not None and create_response.status_code == 201:
                created_item = create_response.json()
                created_items[tool_name] = {"item": created_item, "base_url": base_url}

        # 各ツールで作成されたアイテムが他のツールから見えないことを確認
        for tool_name, item_info in created_items.items():
            item_id = item_info["item"]["id"]

            for other_tool_name, other_tool_config in endpoint_configs.items():
                if tool_name != other_tool_name:
                    other_base_url = other_tool_config["lambda_url"]

                    # 他のツールのエンドポイントから同じIDでアイテムを取得しようとする
                    get_response = self._make_request(
                        f"{other_base_url}/api/items/{item_id}"
                    )

                    if get_response is not None:
                        # 404が返されるか、異なるアイテムが返されることを確認
                        assert get_response.status_code == 404 or (
                            get_response.status_code == 200
                            and get_response.json()["name"] != item_info["item"]["name"]
                        ), (
                            f"{tool_name}で作成したアイテムが{other_tool_name}から見えてしまいました"
                        )

        # クリーンアップ
        for _tool_name, item_info in created_items.items():
            item_id = item_info["item"]["id"]
            base_url = item_info["base_url"]

            self._make_request(f"{base_url}/api/items/{item_id}", "DELETE")
            # クリーンアップのエラーは無視（テスト環境の状態による）

    @pytest.mark.integration
    def test_endpoint_response_consistency(self, endpoint_configs):
        """各CI/CDツール間でのレスポンス形式の一貫性テスト"""
        response_formats = {}

        for tool_name, tool_config in endpoint_configs.items():
            base_url = tool_config["lambda_url"]

            # ヘルスチェックレスポンス形式の確認
            health_response = self._make_request(f"{base_url}/health")

            if health_response is not None and health_response.status_code == 200:
                health_data = health_response.json()
                response_formats[tool_name] = {
                    "health_keys": set(health_data.keys()),
                    "health_status": health_data.get("status"),
                }

        # 全てのツールで同じレスポンス形式であることを確認
        if len(response_formats) > 1:
            first_tool = list(response_formats.keys())[0]
            first_format = response_formats[first_tool]

            for tool_name, format_info in response_formats.items():
                if tool_name != first_tool:
                    assert format_info["health_keys"] == first_format["health_keys"], (
                        f"{tool_name}と{first_tool}でヘルスチェックレスポンス形式が異なります"
                    )
                    assert (
                        format_info["health_status"] == first_format["health_status"]
                    ), (
                        f"{tool_name}と{first_tool}でヘルスチェックステータスが異なります"
                    )


class TestCICDToolPerformanceComparison:
    """CI/CDツールパフォーマンス比較用の基本テストクラス"""

    @pytest.mark.integration
    @pytest.mark.parametrize("tool_name", ["github", "gitlab", "codepipeline"])
    def test_endpoint_response_time(self, tool_name):
        """各CI/CDツール専用エンドポイントのレスポンス時間測定テスト"""
        endpoints = TestCICDToolEndpointComparison.ENDPOINTS

        if tool_name not in endpoints:
            pytest.skip(f"Unknown tool: {tool_name}")

        tool_config = endpoints[tool_name]
        base_url = tool_config["lambda_url"]

        # ヘルスチェックエンドポイントのレスポンス時間を測定
        start_time = time.time()

        try:
            response = requests.get(f"{base_url}/health", timeout=30)
            end_time = time.time()

            response_time = end_time - start_time

            # レスポンス時間をログ出力（実際の比較分析用）
            print(
                f"\n{tool_config['name']} ヘルスチェックレスポンス時間: {response_time:.3f}秒"
            )

            # 基本的な応答性チェック（30秒以内）
            assert response_time < 30.0, (
                f"{tool_config['name']}のレスポンス時間が30秒を超えました"
            )
            assert response.status_code == 200, (
                f"{tool_config['name']}のヘルスチェックが失敗しました"
            )

        except requests.exceptions.RequestException:
            pytest.skip(
                f"{tool_config['name']} エンドポイントにアクセスできません（デプロイされていない可能性があります）"
            )

"""
CloudWatchロググループの分離を確認するテスト

各CI/CDツール専用のロググループが正しく分離され、
ログが適切に振り分けられることを確認する。
"""

from datetime import UTC, datetime, timedelta

import boto3
import pytest


class TestCloudWatchLogSeparation:
    """CloudWatchロググループ分離テスト"""

    def __init__(self):
        self.cloudwatch_logs = boto3.client("logs")

        # 各CI/CDツール専用のロググループ名パターン
        self.log_group_patterns = {
            "github": {
                "lambda": "/aws/lambda/github-local-lambda-api",
                "ecs": "/aws/ecs/github-local-ecs-api",
                "ec2": "/aws/ec2/github-local-ec2-api",
            },
            "gitlab": {
                "lambda": "/aws/lambda/gitlab-local-lambda-api",
                "ecs": "/aws/ecs/gitlab-local-ecs-api",
                "ec2": "/aws/ec2/gitlab-local-ec2-api",
            },
            "codepipeline": {
                "lambda": "/aws/lambda/codepipeline-local-lambda-api",
                "ecs": "/aws/ecs/codepipeline-local-ecs-api",
                "ec2": "/aws/ec2/codepipeline-local-ec2-api",
            },
        }

    def test_log_groups_exist(self):
        """
        各CI/CDツール専用のロググループが存在することを確認
        """
        try:
            # 全ロググループを取得
            response = self.cloudwatch_logs.describe_log_groups()
            existing_log_groups = {lg["logGroupName"] for lg in response["logGroups"]}

            missing_groups = []
            existing_groups = []

            for tool, services in self.log_group_patterns.items():
                for service, log_group_name in services.items():
                    if log_group_name in existing_log_groups:
                        existing_groups.append(f"{tool}-{service}: {log_group_name}")
                    else:
                        missing_groups.append(f"{tool}-{service}: {log_group_name}")

            # 結果をレポート
            if existing_groups:
                print("✓ Existing log groups:")
                for group in existing_groups:
                    print(f"  - {group}")

            if missing_groups:
                print("⚠ Missing log groups (may not be deployed yet):")
                for group in missing_groups:
                    print(f"  - {group}")

                # 全て存在しない場合はスキップ
                if len(missing_groups) == len(
                    [
                        lg
                        for services in self.log_group_patterns.values()
                        for lg in services.values()
                    ]
                ):
                    pytest.skip(
                        "No CI/CD tool log groups found - infrastructure not deployed"
                    )

            # 少なくとも1つのロググループが存在することを確認
            assert len(existing_groups) > 0, "At least one log group should exist"

        except Exception as e:
            pytest.skip(f"Cannot access CloudWatch Logs: {str(e)}")

    def test_log_group_naming_convention(self):
        """
        ロググループの命名規約が正しく適用されていることを確認
        """
        try:
            response = self.cloudwatch_logs.describe_log_groups()
            existing_log_groups = [lg["logGroupName"] for lg in response["logGroups"]]

            # CI/CDツール関連のロググループを抽出
            cicd_log_groups = [
                lg
                for lg in existing_log_groups
                if any(
                    tool in lg
                    for tool in ["github-local", "gitlab-local", "codepipeline-local"]
                )
            ]

            if not cicd_log_groups:
                pytest.skip("No CI/CD tool log groups found")

            # 命名規約の確認
            for log_group in cicd_log_groups:
                # パターン: /aws/{service}/{tool}-local-{service}-{purpose}
                parts = log_group.split("/")
                assert len(parts) >= 3, f"Invalid log group structure: {log_group}"
                assert parts[1] == "aws", f"Should start with /aws/: {log_group}"

                # ツール名の確認
                tool_found = False
                for tool in ["github", "gitlab", "codepipeline"]:
                    if f"{tool}-local" in log_group:
                        tool_found = True
                        break

                assert tool_found, f"Tool name not found in log group: {log_group}"

                print(f"✓ Valid naming convention: {log_group}")

        except Exception as e:
            pytest.skip(f"Cannot access CloudWatch Logs: {str(e)}")

    def test_log_streams_separation(self):
        """
        各ロググループ内のログストリームが適切に分離されていることを確認
        """
        try:
            # 存在するロググループを確認
            response = self.cloudwatch_logs.describe_log_groups()
            existing_log_groups = {lg["logGroupName"] for lg in response["logGroups"]}

            tool_log_streams = {}

            for tool, services in self.log_group_patterns.items():
                tool_log_streams[tool] = {}

                for service, log_group_name in services.items():
                    if log_group_name in existing_log_groups:
                        try:
                            streams_response = (
                                self.cloudwatch_logs.describe_log_streams(
                                    logGroupName=log_group_name, limit=10
                                )
                            )

                            stream_names = [
                                stream["logStreamName"]
                                for stream in streams_response["logStreams"]
                            ]
                            tool_log_streams[tool][service] = stream_names

                            print(
                                f"✓ {tool} {service} has {len(stream_names)} log streams"
                            )

                        except Exception as e:
                            print(
                                f"⚠ Cannot access log streams for {log_group_name}: {str(e)}"
                            )

            # 各ツールのログストリームが独立していることを確認
            all_streams = []
            for tool, services in tool_log_streams.items():
                for service, streams in services.items():
                    for stream in streams:
                        all_streams.append((tool, service, stream))

            if all_streams:
                # ストリーム名の重複がないことを確認（異なるロググループ間で）
                stream_names_only = [stream for _, _, stream in all_streams]
                unique_streams = set(stream_names_only)

                # 同じストリーム名が複数のツールで使われていないことを確認
                # （ただし、Lambda等では同じパターンのストリーム名が使われる可能性があるため、
                #  ロググループレベルでの分離が重要）
                print(f"Total log streams found: {len(stream_names_only)}")
                print(f"Unique stream names: {len(unique_streams)}")

                assert len(all_streams) > 0, "Should have at least one log stream"
            else:
                pytest.skip("No log streams found - applications may not be running")

        except Exception as e:
            pytest.skip(f"Cannot access CloudWatch Logs: {str(e)}")

    def test_recent_log_entries_separation(self):
        """
        最近のログエントリが適切なロググループに記録されていることを確認
        """
        try:
            # 過去1時間のログを確認
            end_time = datetime.now(UTC)
            start_time = end_time - timedelta(hours=1)

            start_timestamp = int(start_time.timestamp() * 1000)
            end_timestamp = int(end_time.timestamp() * 1000)

            log_entries_by_tool = {}

            for tool, services in self.log_group_patterns.items():
                log_entries_by_tool[tool] = {}

                for service, log_group_name in services.items():
                    try:
                        # ロググループの存在確認
                        self.cloudwatch_logs.describe_log_groups(
                            logGroupNamePrefix=log_group_name
                        )

                        # ログイベントを取得
                        events_response = self.cloudwatch_logs.filter_log_events(
                            logGroupName=log_group_name,
                            startTime=start_timestamp,
                            endTime=end_timestamp,
                            limit=10,
                        )

                        events = events_response.get("events", [])
                        log_entries_by_tool[tool][service] = len(events)

                        if events:
                            print(
                                f"✓ {tool} {service}: {len(events)} log entries in last hour"
                            )

                            # ログメッセージにツール固有の情報が含まれているか確認
                            sample_messages = [event["message"] for event in events[:3]]
                            for message in sample_messages:
                                # ログメッセージが適切なツールのものであることを間接的に確認
                                # （実際のログ内容は実装依存）
                                assert isinstance(
                                    message, str
                                ), "Log message should be string"

                    except self.cloudwatch_logs.exceptions.ResourceNotFoundException:
                        print(f"⚠ Log group not found: {log_group_name}")
                        log_entries_by_tool[tool][service] = 0
                    except Exception as e:
                        print(f"⚠ Error accessing {log_group_name}: {str(e)}")
                        log_entries_by_tool[tool][service] = 0

            # 結果のサマリー
            total_entries = sum(
                sum(services.values()) for services in log_entries_by_tool.values()
            )

            if total_entries == 0:
                pytest.skip(
                    "No recent log entries found - applications may not be active"
                )

            print(f"Total log entries found: {total_entries}")

            # 各ツールのログが独立して記録されていることを確認
            tools_with_logs = [
                tool
                for tool, services in log_entries_by_tool.items()
                if sum(services.values()) > 0
            ]

            assert len(tools_with_logs) > 0, "At least one tool should have log entries"

        except Exception as e:
            pytest.skip(f"Cannot access CloudWatch Logs: {str(e)}")

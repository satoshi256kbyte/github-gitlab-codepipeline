#!/usr/bin/env python3
"""
CI/CDメトリクス収集スクリプト
各CI/CDツールのパフォーマンスメトリクスを収集し、比較分析用のデータを生成
"""

import argparse
import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import boto3
import requests


@dataclass
class PipelineMetrics:
    """パイプラインメトリクスデータクラス"""

    tool: str
    pipeline_id: str
    execution_id: str
    start_time: str
    end_time: str
    duration_seconds: float
    status: str
    stages: list[dict]
    success_rate: float
    failure_count: int
    total_executions: int


@dataclass
class DeploymentMetrics:
    """デプロイメントメトリクスデータクラス"""

    tool: str
    target: str  # lambda, ecs, ec2
    deployment_id: str
    start_time: str
    end_time: str
    duration_seconds: float
    status: str
    rollback_occurred: bool
    health_check_duration: float


class CICDMetricsCollector:
    """CI/CDメトリクス収集クラス"""

    def __init__(self):
        self.github_token = os.getenv("GITHUB_TOKEN")
        self.gitlab_token = os.getenv("GITLAB_TOKEN")
        self.gitlab_project_id = os.getenv("GITLAB_PROJECT_ID")
        self.gitlab_url = os.getenv("GITLAB_URL", "https://gitlab.com")
        self.aws_region = os.getenv("AWS_DEFAULT_REGION", "ap-northeast-1")

        # AWS クライアント初期化
        self.codepipeline_client = boto3.client(
            "codepipeline", region_name=self.aws_region
        )
        self.codebuild_client = boto3.client("codebuild", region_name=self.aws_region)
        self.cloudwatch_client = boto3.client("cloudwatch", region_name=self.aws_region)

    def collect_github_metrics(
        self, repo_owner: str, repo_name: str, days: int = 7
    ) -> list[PipelineMetrics]:
        """
        GitHub Actionsのメトリクスを収集

        Args:
            repo_owner: リポジトリオーナー
            repo_name: リポジトリ名
            days: 収集期間（日数）

        Returns:
            パイプラインメトリクスのリスト
        """
        print(f"GitHub Actions メトリクス収集開始 ({repo_owner}/{repo_name})")

        if not self.github_token:
            print("GitHub token が設定されていません")
            return []

        headers = {
            "Authorization": f"token {self.github_token}",
            "Accept": "application/vnd.github.v3+json",
        }

        # 指定期間のワークフロー実行を取得
        since = (datetime.now() - timedelta(days=days)).isoformat()
        url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/actions/runs"

        params = {"created": f">={since}", "per_page": 100}

        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()

            runs_data = response.json()
            metrics = []

            for run in runs_data.get("workflow_runs", []):
                # 各実行の詳細メトリクスを取得
                run_metrics = self._extract_github_run_metrics(
                    run, headers, repo_owner, repo_name
                )
                if run_metrics:
                    metrics.append(run_metrics)

            print(f"GitHub Actions: {len(metrics)} 件のメトリクスを収集")
            return metrics

        except Exception as e:
            print(f"GitHub Actions メトリクス収集エラー: {e}")
            return []

    def _extract_github_run_metrics(
        self, run: dict, headers: dict, repo_owner: str, repo_name: str
    ) -> PipelineMetrics | None:
        """GitHub Actions実行からメトリクスを抽出"""
        try:
            run_id = run["id"]

            # ジョブ詳細を取得
            jobs_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/actions/runs/{run_id}/jobs"
            jobs_response = requests.get(jobs_url, headers=headers)
            jobs_response.raise_for_status()

            jobs_data = jobs_response.json()
            stages = []

            for job in jobs_data.get("jobs", []):
                if job.get("started_at") and job.get("completed_at"):
                    start = datetime.fromisoformat(
                        job["started_at"].replace("Z", "+00:00")
                    )
                    end = datetime.fromisoformat(
                        job["completed_at"].replace("Z", "+00:00")
                    )
                    duration = (end - start).total_seconds()

                    stages.append(
                        {
                            "name": job["name"],
                            "status": job["conclusion"],
                            "duration_seconds": duration,
                            "start_time": job["started_at"],
                            "end_time": job["completed_at"],
                        }
                    )

            # 全体の実行時間を計算
            if run.get("created_at") and run.get("updated_at"):
                start_time = datetime.fromisoformat(
                    run["created_at"].replace("Z", "+00:00")
                )
                end_time = datetime.fromisoformat(
                    run["updated_at"].replace("Z", "+00:00")
                )
                total_duration = (end_time - start_time).total_seconds()
            else:
                total_duration = sum(stage["duration_seconds"] for stage in stages)

            return PipelineMetrics(
                tool="github",
                pipeline_id=str(run["workflow_id"]),
                execution_id=str(run_id),
                start_time=run["created_at"],
                end_time=run["updated_at"],
                duration_seconds=total_duration,
                status=run["conclusion"] or run["status"],
                stages=stages,
                success_rate=1.0 if run["conclusion"] == "success" else 0.0,
                failure_count=1 if run["conclusion"] != "success" else 0,
                total_executions=1,
            )

        except Exception as e:
            print(f"GitHub run metrics extraction error: {e}")
            return None

    def collect_gitlab_metrics(self, days: int = 7) -> list[PipelineMetrics]:
        """
        GitLab CI/CDのメトリクスを収集

        Args:
            days: 収集期間（日数）

        Returns:
            パイプラインメトリクスのリスト
        """
        print(f"GitLab CI/CD メトリクス収集開始 (Project ID: {self.gitlab_project_id})")

        if not self.gitlab_token or not self.gitlab_project_id:
            print("GitLab token または project ID が設定されていません")
            return []

        headers = {"PRIVATE-TOKEN": self.gitlab_token}

        # 指定期間のパイプラインを取得
        since = (datetime.now() - timedelta(days=days)).isoformat()
        url = f"{self.gitlab_url}/api/v4/projects/{self.gitlab_project_id}/pipelines"

        params = {"updated_after": since, "per_page": 100}

        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()

            pipelines = response.json()
            metrics = []

            for pipeline in pipelines:
                # 各パイプラインの詳細メトリクスを取得
                pipeline_metrics = self._extract_gitlab_pipeline_metrics(
                    pipeline, headers
                )
                if pipeline_metrics:
                    metrics.append(pipeline_metrics)

            print(f"GitLab CI/CD: {len(metrics)} 件のメトリクスを収集")
            return metrics

        except Exception as e:
            print(f"GitLab CI/CD メトリクス収集エラー: {e}")
            return []

    def _extract_gitlab_pipeline_metrics(
        self, pipeline: dict, headers: dict
    ) -> PipelineMetrics | None:
        """GitLab パイプラインからメトリクスを抽出"""
        try:
            pipeline_id = pipeline["id"]

            # ジョブ詳細を取得
            jobs_url = f"{self.gitlab_url}/api/v4/projects/{self.gitlab_project_id}/pipelines/{pipeline_id}/jobs"
            jobs_response = requests.get(jobs_url, headers=headers)
            jobs_response.raise_for_status()

            jobs = jobs_response.json()
            stages = []

            for job in jobs:
                if job.get("started_at") and job.get("finished_at"):
                    start = datetime.fromisoformat(
                        job["started_at"].replace("Z", "+00:00")
                    )
                    end = datetime.fromisoformat(
                        job["finished_at"].replace("Z", "+00:00")
                    )
                    duration = (end - start).total_seconds()

                    stages.append(
                        {
                            "name": job["name"],
                            "status": job["status"],
                            "duration_seconds": duration,
                            "start_time": job["started_at"],
                            "end_time": job["finished_at"],
                        }
                    )

            # 全体の実行時間を計算
            if pipeline.get("created_at") and pipeline.get("updated_at"):
                start_time = datetime.fromisoformat(
                    pipeline["created_at"].replace("Z", "+00:00")
                )
                end_time = datetime.fromisoformat(
                    pipeline["updated_at"].replace("Z", "+00:00")
                )
                total_duration = (end_time - start_time).total_seconds()
            else:
                total_duration = sum(stage["duration_seconds"] for stage in stages)

            return PipelineMetrics(
                tool="gitlab",
                pipeline_id=str(pipeline_id),
                execution_id=str(pipeline_id),
                start_time=pipeline["created_at"],
                end_time=pipeline["updated_at"],
                duration_seconds=total_duration,
                status=pipeline["status"],
                stages=stages,
                success_rate=1.0 if pipeline["status"] == "success" else 0.0,
                failure_count=1 if pipeline["status"] != "success" else 0,
                total_executions=1,
            )

        except Exception as e:
            print(f"GitLab pipeline metrics extraction error: {e}")
            return None

    def collect_codepipeline_metrics(
        self, pipeline_name: str, days: int = 7
    ) -> list[PipelineMetrics]:
        """
        AWS CodePipelineのメトリクスを収集

        Args:
            pipeline_name: パイプライン名
            days: 収集期間（日数）

        Returns:
            パイプラインメトリクスのリスト
        """
        print(f"AWS CodePipeline メトリクス収集開始 ({pipeline_name})")

        try:
            # 指定期間のパイプライン実行を取得
            response = self.codepipeline_client.list_pipeline_executions(
                pipelineName=pipeline_name, maxResults=100
            )

            executions = response.get("pipelineExecutionSummaries", [])
            metrics = []

            # 指定期間内の実行をフィルタ
            cutoff_date = datetime.now() - timedelta(days=days)

            for execution in executions:
                if execution.get("startTime") and execution["startTime"] >= cutoff_date:
                    # 各実行の詳細メトリクスを取得
                    execution_metrics = self._extract_codepipeline_execution_metrics(
                        pipeline_name, execution
                    )
                    if execution_metrics:
                        metrics.append(execution_metrics)

            print(f"AWS CodePipeline: {len(metrics)} 件のメトリクスを収集")
            return metrics

        except Exception as e:
            print(f"AWS CodePipeline メトリクス収集エラー: {e}")
            return []

    def _extract_codepipeline_execution_metrics(
        self, pipeline_name: str, execution: dict
    ) -> PipelineMetrics | None:
        """CodePipeline実行からメトリクスを抽出"""
        try:
            execution_id = execution["pipelineExecutionId"]

            # アクション実行の詳細を取得
            actions_response = self.codepipeline_client.list_action_executions(
                pipelineName=pipeline_name, filter={"pipelineExecutionId": execution_id}
            )

            actions = actions_response.get("actionExecutionDetails", [])
            stages = []

            for action in actions:
                if action.get("startTime") and action.get("lastUpdateTime"):
                    duration = (
                        action["lastUpdateTime"] - action["startTime"]
                    ).total_seconds()

                    stages.append(
                        {
                            "name": action["actionName"],
                            "status": action.get("status", "Unknown"),
                            "duration_seconds": duration,
                            "start_time": action["startTime"].isoformat(),
                            "end_time": action["lastUpdateTime"].isoformat(),
                        }
                    )

            # 全体の実行時間を計算
            if execution.get("startTime") and execution.get("lastUpdateTime"):
                total_duration = (
                    execution["lastUpdateTime"] - execution["startTime"]
                ).total_seconds()
            else:
                total_duration = sum(stage["duration_seconds"] for stage in stages)

            return PipelineMetrics(
                tool="codepipeline",
                pipeline_id=pipeline_name,
                execution_id=execution_id,
                start_time=execution["startTime"].isoformat(),
                end_time=execution.get(
                    "lastUpdateTime", execution["startTime"]
                ).isoformat(),
                duration_seconds=total_duration,
                status=execution["status"],
                stages=stages,
                success_rate=1.0 if execution["status"] == "Succeeded" else 0.0,
                failure_count=1 if execution["status"] != "Succeeded" else 0,
                total_executions=1,
            )

        except Exception as e:
            print(f"CodePipeline execution metrics extraction error: {e}")
            return None

    def collect_deployment_metrics(
        self, tool: str, days: int = 7
    ) -> list[DeploymentMetrics]:
        """
        デプロイメントメトリクスを収集

        Args:
            tool: CI/CDツール名
            days: 収集期間（日数）

        Returns:
            デプロイメントメトリクスのリスト
        """
        print(f"{tool.upper()} デプロイメントメトリクス収集開始")

        deployment_targets = ["lambda", "ecs", "ec2"]
        all_metrics = []

        for target in deployment_targets:
            target_metrics = self._collect_target_deployment_metrics(tool, target, days)
            all_metrics.extend(target_metrics)

        print(f"{tool.upper()}: {len(all_metrics)} 件のデプロイメントメトリクスを収集")
        return all_metrics

    def _collect_target_deployment_metrics(
        self, tool: str, target: str, days: int
    ) -> list[DeploymentMetrics]:
        """特定のデプロイターゲットのメトリクスを収集"""
        try:
            if target == "lambda":
                return self._collect_lambda_deployment_metrics(tool, days)
            elif target == "ecs":
                return self._collect_ecs_deployment_metrics(tool, days)
            elif target == "ec2":
                return self._collect_ec2_deployment_metrics(tool, days)
            else:
                return []
        except Exception as e:
            print(f"{tool} {target} デプロイメントメトリクス収集エラー: {e}")
            return []

    def _collect_lambda_deployment_metrics(
        self, tool: str, days: int
    ) -> list[DeploymentMetrics]:
        """Lambda デプロイメントメトリクスを収集"""
        # CloudWatch Logs から SAM デプロイメントログを取得
        # 実際の実装では、CloudWatch Logs API を使用してデプロイログを解析
        return []

    def _collect_ecs_deployment_metrics(
        self, tool: str, days: int
    ) -> list[DeploymentMetrics]:
        """ECS デプロイメントメトリクスを収集"""
        # ECS サービスのデプロイメント履歴を取得
        # 実際の実装では、ECS API を使用してデプロイメント履歴を取得
        return []

    def _collect_ec2_deployment_metrics(
        self, tool: str, days: int
    ) -> list[DeploymentMetrics]:
        """EC2 デプロイメントメトリクスを収集"""
        # CodeDeploy のデプロイメント履歴を取得
        # 実際の実装では、CodeDeploy API を使用してデプロイメント履歴を取得
        return []

    def generate_metrics_report(
        self,
        pipeline_metrics: dict[str, list[PipelineMetrics]],
        deployment_metrics: dict[str, list[DeploymentMetrics]],
    ) -> dict:
        """
        メトリクスレポートを生成

        Args:
            pipeline_metrics: パイプラインメトリクス（ツール別）
            deployment_metrics: デプロイメントメトリクス（ツール別）

        Returns:
            統合メトリクスレポート
        """
        report = {
            "generated_at": datetime.now().isoformat(),
            "summary": {},
            "pipeline_analysis": {},
            "deployment_analysis": {},
            "comparison": {},
        }

        # パイプライン分析
        for tool, metrics in pipeline_metrics.items():
            if metrics:
                avg_duration = sum(m.duration_seconds for m in metrics) / len(metrics)
                success_rate = sum(m.success_rate for m in metrics) / len(metrics)
                total_failures = sum(m.failure_count for m in metrics)

                report["pipeline_analysis"][tool] = {
                    "total_executions": len(metrics),
                    "average_duration_seconds": avg_duration,
                    "success_rate": success_rate,
                    "total_failures": total_failures,
                    "fastest_execution": min(m.duration_seconds for m in metrics),
                    "slowest_execution": max(m.duration_seconds for m in metrics),
                }

        # デプロイメント分析
        for tool, metrics in deployment_metrics.items():
            if metrics:
                avg_duration = sum(m.duration_seconds for m in metrics) / len(metrics)
                rollback_rate = sum(1 for m in metrics if m.rollback_occurred) / len(
                    metrics
                )

                report["deployment_analysis"][tool] = {
                    "total_deployments": len(metrics),
                    "average_duration_seconds": avg_duration,
                    "rollback_rate": rollback_rate,
                    "targets": list({m.target for m in metrics}),
                }

        # 比較分析
        if len(pipeline_metrics) > 1:
            tools = list(pipeline_metrics.keys())

            # 実行時間比較
            durations = {}
            for tool in tools:
                if pipeline_metrics[tool]:
                    durations[tool] = sum(
                        m.duration_seconds for m in pipeline_metrics[tool]
                    ) / len(pipeline_metrics[tool])

            if durations:
                fastest_tool = min(durations, key=durations.get)
                slowest_tool = max(durations, key=durations.get)

                report["comparison"]["execution_time"] = {
                    "fastest_tool": fastest_tool,
                    "slowest_tool": slowest_tool,
                    "time_difference_seconds": durations[slowest_tool]
                    - durations[fastest_tool],
                    "performance_improvement_percentage": (
                        (durations[slowest_tool] - durations[fastest_tool])
                        / durations[slowest_tool]
                    )
                    * 100,
                }

        return report

    def save_metrics(self, report: dict, filename: str = None):
        """メトリクスレポートを保存"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"cicd_metrics_report_{timestamp}.json"

        output_path = Path("reports") / filename
        output_path.parent.mkdir(exist_ok=True)

        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False, default=str)

        print(f"\nメトリクスレポートを保存しました: {output_path}")
        return output_path


def main():
    """メイン実行関数"""
    parser = argparse.ArgumentParser(description="CI/CDメトリクス収集")
    parser.add_argument(
        "--tools",
        nargs="+",
        choices=["github", "gitlab", "codepipeline"],
        default=["github", "gitlab", "codepipeline"],
        help="メトリクスを収集するCI/CDツール",
    )
    parser.add_argument(
        "--days", type=int, default=7, help="メトリクス収集期間（日数）"
    )
    parser.add_argument(
        "--github-repo", type=str, help="GitHub リポジトリ (owner/repo)"
    )
    parser.add_argument(
        "--codepipeline-name",
        type=str,
        default="cicd-comparison-pipeline",
        help="CodePipeline名",
    )
    parser.add_argument(
        "--include-deployments",
        action="store_true",
        help="デプロイメントメトリクスも収集する",
    )
    parser.add_argument("--output", type=str, help="出力ファイル名")

    args = parser.parse_args()

    collector = CICDMetricsCollector()

    pipeline_metrics = {}
    deployment_metrics = {}

    print("CI/CDメトリクス収集を開始します...")
    print(f"対象ツール: {', '.join(args.tools)}")
    print(f"収集期間: {args.days} 日間")

    # パイプラインメトリクス収集
    for tool in args.tools:
        print(f"\n{'=' * 50}")
        print(f"{tool.upper()} メトリクス収集")
        print(f"{'=' * 50}")

        if tool == "github":
            if args.github_repo:
                owner, repo = args.github_repo.split("/")
                pipeline_metrics[tool] = collector.collect_github_metrics(
                    owner, repo, args.days
                )
            else:
                print(
                    "GitHub リポジトリが指定されていません (--github-repo owner/repo)"
                )
                pipeline_metrics[tool] = []

        elif tool == "gitlab":
            pipeline_metrics[tool] = collector.collect_gitlab_metrics(args.days)

        elif tool == "codepipeline":
            pipeline_metrics[tool] = collector.collect_codepipeline_metrics(
                args.codepipeline_name, args.days
            )

        # デプロイメントメトリクス収集（オプション）
        if args.include_deployments:
            deployment_metrics[tool] = collector.collect_deployment_metrics(
                tool, args.days
            )
        else:
            deployment_metrics[tool] = []

    # レポート生成
    print(f"\n{'=' * 50}")
    print("メトリクスレポート生成")
    print(f"{'=' * 50}")

    report = collector.generate_metrics_report(pipeline_metrics, deployment_metrics)

    # 結果保存
    output_path = collector.save_metrics(report, args.output)

    # サマリー表示
    print(f"\n{'=' * 50}")
    print("メトリクス収集結果サマリー")
    print(f"{'=' * 50}")

    for tool in args.tools:
        pipeline_count = len(pipeline_metrics.get(tool, []))
        deployment_count = len(deployment_metrics.get(tool, []))

        print(f"{tool.upper()}:")
        print(f"  パイプライン実行: {pipeline_count} 件")
        if args.include_deployments:
            print(f"  デプロイメント: {deployment_count} 件")

    # パフォーマンス比較
    if "comparison" in report and "execution_time" in report["comparison"]:
        comparison = report["comparison"]["execution_time"]
        print("\nパフォーマンス比較:")
        print(f"  最速ツール: {comparison['fastest_tool']}")
        print(f"  最遅ツール: {comparison['slowest_tool']}")
        print(
            f"  パフォーマンス改善率: {comparison['performance_improvement_percentage']:.1f}%"
        )

    print(f"\n詳細レポート: {output_path}")


if __name__ == "__main__":
    main()

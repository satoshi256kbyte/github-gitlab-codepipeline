#!/usr/bin/env python3
"""
CI/CDツールパフォーマンス比較スクリプト
各CI/CDツールのパイプライン実行時間を測定し、デプロイ速度を比較する
"""

import json
import time
import subprocess
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import argparse
import sys
import os
from pathlib import Path


class CICDPerformanceAnalyzer:
    """CI/CDパフォーマンス分析クラス"""
    
    def __init__(self):
        self.results = {
            "github": {},
            "gitlab": {},
            "codepipeline": {}
        }
        self.start_times = {}
        self.endpoints = {
            "github": {
                "name": "GitHub Actions",
                "lambda_url": "https://github-local-api.execute-api.us-east-1.amazonaws.com/prod",
                "alb_url": "http://github-local-alb-api.example.com",
                "port": 8080
            },
            "gitlab": {
                "name": "GitLab CI/CD",
                "lambda_url": "https://gitlab-local-api.execute-api.us-east-1.amazonaws.com/prod",
                "alb_url": "http://gitlab-local-alb-api.example.com",
                "port": 8081
            },
            "codepipeline": {
                "name": "CodePipeline",
                "lambda_url": "https://codepipeline-local-api.execute-api.us-east-1.amazonaws.com/prod",
                "alb_url": "http://codepipeline-local-alb-api.example.com",
                "port": 8082
            }
        }
    
    def measure_pipeline_execution_time(self, tool: str) -> Dict:
        """
        CI/CDパイプラインの実行時間を測定
        
        Args:
            tool: CI/CDツール名 (github, gitlab, codepipeline)
            
        Returns:
            実行時間の測定結果
        """
        print(f"\n=== {self.endpoints[tool]['name']} パイプライン実行時間測定開始 ===")
        
        start_time = datetime.now()
        
        try:
            if tool == "github":
                execution_result = self._measure_github_actions()
            elif tool == "gitlab":
                execution_result = self._measure_gitlab_cicd()
            elif tool == "codepipeline":
                execution_result = self._measure_codepipeline()
            else:
                raise ValueError(f"Unknown tool: {tool}")
            
            end_time = datetime.now()
            total_duration = (end_time - start_time).total_seconds()
            
            result = {
                "tool": tool,
                "tool_name": self.endpoints[tool]["name"],
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "total_duration_seconds": total_duration,
                "execution_details": execution_result,
                "status": "success" if execution_result.get("success", False) else "failed"
            }
            
            print(f"{self.endpoints[tool]['name']} 実行時間: {total_duration:.2f}秒")
            return result
            
        except Exception as e:
            end_time = datetime.now()
            total_duration = (end_time - start_time).total_seconds()
            
            result = {
                "tool": tool,
                "tool_name": self.endpoints[tool]["name"],
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "total_duration_seconds": total_duration,
                "error": str(e),
                "status": "error"
            }
            
            print(f"{self.endpoints[tool]['name']} 実行エラー: {e}")
            return result
    
    def _measure_github_actions(self) -> Dict:
        """GitHub Actionsパイプラインの実行時間測定"""
        print("GitHub Actionsワークフロー実行を開始...")
        
        # GitHub CLIを使用してワークフローを実行
        try:
            # 最新のワークフロー実行を取得
            result = subprocess.run([
                "gh", "run", "list", "--workflow=ci.yml", "--limit=1", "--json=status,conclusion,createdAt,updatedAt,databaseId"
            ], capture_output=True, text=True, check=True)
            
            runs = json.loads(result.stdout)
            if not runs:
                return {"success": False, "error": "No workflow runs found"}
            
            latest_run = runs[0]
            
            # ワークフロー実行の詳細を取得
            run_details = subprocess.run([
                "gh", "run", "view", str(latest_run["databaseId"]), "--json=jobs"
            ], capture_output=True, text=True, check=True)
            
            jobs_data = json.loads(run_details.stdout)
            
            # 各ジョブの実行時間を計算
            job_durations = {}
            total_job_time = 0
            
            for job in jobs_data.get("jobs", []):
                if job.get("startedAt") and job.get("completedAt"):
                    start = datetime.fromisoformat(job["startedAt"].replace("Z", "+00:00"))
                    end = datetime.fromisoformat(job["completedAt"].replace("Z", "+00:00"))
                    duration = (end - start).total_seconds()
                    job_durations[job["name"]] = duration
                    total_job_time += duration
            
            return {
                "success": latest_run["status"] == "completed" and latest_run["conclusion"] == "success",
                "workflow_status": latest_run["status"],
                "workflow_conclusion": latest_run["conclusion"],
                "job_durations": job_durations,
                "total_job_time_seconds": total_job_time,
                "parallel_execution": len(job_durations) > 1
            }
            
        except subprocess.CalledProcessError as e:
            return {"success": False, "error": f"GitHub CLI error: {e}"}
        except Exception as e:
            return {"success": False, "error": f"Unexpected error: {e}"}
    
    def _measure_gitlab_cicd(self) -> Dict:
        """GitLab CI/CDパイプラインの実行時間測定"""
        print("GitLab CI/CDパイプライン実行を開始...")
        
        # GitLab APIを使用してパイプライン情報を取得
        try:
            # 環境変数からGitLab設定を取得
            gitlab_token = os.getenv("GITLAB_TOKEN")
            gitlab_project_id = os.getenv("GITLAB_PROJECT_ID")
            gitlab_url = os.getenv("GITLAB_URL", "https://gitlab.com")
            
            if not gitlab_token or not gitlab_project_id:
                return {"success": False, "error": "GitLab token or project ID not configured"}
            
            headers = {"PRIVATE-TOKEN": gitlab_token}
            
            # 最新のパイプラインを取得
            pipelines_url = f"{gitlab_url}/api/v4/projects/{gitlab_project_id}/pipelines"
            response = requests.get(pipelines_url, headers=headers, params={"per_page": 1})
            
            if response.status_code != 200:
                return {"success": False, "error": f"Failed to fetch pipelines: {response.status_code}"}
            
            pipelines = response.json()
            if not pipelines:
                return {"success": False, "error": "No pipelines found"}
            
            latest_pipeline = pipelines[0]
            pipeline_id = latest_pipeline["id"]
            
            # パイプラインのジョブ詳細を取得
            jobs_url = f"{gitlab_url}/api/v4/projects/{gitlab_project_id}/pipelines/{pipeline_id}/jobs"
            jobs_response = requests.get(jobs_url, headers=headers)
            
            if jobs_response.status_code != 200:
                return {"success": False, "error": f"Failed to fetch jobs: {jobs_response.status_code}"}
            
            jobs = jobs_response.json()
            
            # 各ジョブの実行時間を計算
            job_durations = {}
            total_job_time = 0
            
            for job in jobs:
                if job.get("started_at") and job.get("finished_at"):
                    start = datetime.fromisoformat(job["started_at"].replace("Z", "+00:00"))
                    end = datetime.fromisoformat(job["finished_at"].replace("Z", "+00:00"))
                    duration = (end - start).total_seconds()
                    job_durations[job["name"]] = duration
                    total_job_time += duration
            
            return {
                "success": latest_pipeline["status"] == "success",
                "pipeline_status": latest_pipeline["status"],
                "job_durations": job_durations,
                "total_job_time_seconds": total_job_time,
                "parallel_execution": len(job_durations) > 1
            }
            
        except Exception as e:
            return {"success": False, "error": f"GitLab API error: {e}"}
    
    def _measure_codepipeline(self) -> Dict:
        """AWS CodePipelineの実行時間測定"""
        print("AWS CodePipeline実行を開始...")
        
        try:
            # AWS CLIを使用してCodePipeline情報を取得
            pipeline_name = os.getenv("CODEPIPELINE_NAME", "cicd-comparison-pipeline")
            
            # 最新のパイプライン実行を取得
            result = subprocess.run([
                "aws", "codepipeline", "list-pipeline-executions",
                "--pipeline-name", pipeline_name,
                "--max-items", "1"
            ], capture_output=True, text=True, check=True)
            
            executions_data = json.loads(result.stdout)
            executions = executions_data.get("pipelineExecutionSummaries", [])
            
            if not executions:
                return {"success": False, "error": "No pipeline executions found"}
            
            latest_execution = executions[0]
            execution_id = latest_execution["pipelineExecutionId"]
            
            # パイプライン実行の詳細を取得
            detail_result = subprocess.run([
                "aws", "codepipeline", "get-pipeline-execution",
                "--pipeline-name", pipeline_name,
                "--pipeline-execution-id", execution_id
            ], capture_output=True, text=True, check=True)
            
            execution_details = json.loads(detail_result.stdout)
            
            # ステージ実行の詳細を取得
            stages_result = subprocess.run([
                "aws", "codepipeline", "list-action-executions",
                "--pipeline-name", pipeline_name,
                "--filter", f"pipelineExecutionId={execution_id}"
            ], capture_output=True, text=True, check=True)
            
            stages_data = json.loads(stages_result.stdout)
            action_executions = stages_data.get("actionExecutionDetails", [])
            
            # 各アクションの実行時間を計算
            action_durations = {}
            total_action_time = 0
            
            for action in action_executions:
                action_name = action["actionName"]
                if action.get("startTime") and action.get("lastUpdateTime"):
                    start = datetime.fromisoformat(action["startTime"].replace("Z", "+00:00"))
                    end = datetime.fromisoformat(action["lastUpdateTime"].replace("Z", "+00:00"))
                    duration = (end - start).total_seconds()
                    action_durations[action_name] = duration
                    total_action_time += duration
            
            return {
                "success": latest_execution["status"] == "Succeeded",
                "pipeline_status": latest_execution["status"],
                "action_durations": action_durations,
                "total_action_time_seconds": total_action_time,
                "parallel_execution": len(action_durations) > 1
            }
            
        except subprocess.CalledProcessError as e:
            return {"success": False, "error": f"AWS CLI error: {e}"}
        except Exception as e:
            return {"success": False, "error": f"Unexpected error: {e}"}
    
    def measure_deployment_speed(self, tool: str) -> Dict:
        """
        デプロイ速度を測定
        
        Args:
            tool: CI/CDツール名
            
        Returns:
            デプロイ速度の測定結果
        """
        print(f"\n=== {self.endpoints[tool]['name']} デプロイ速度測定開始 ===")
        
        deployment_targets = ["lambda", "ecs", "ec2"]
        results = {}
        
        for target in deployment_targets:
            print(f"{target.upper()}デプロイ速度測定中...")
            
            start_time = time.time()
            
            # デプロイ前の状態確認
            pre_deploy_status = self._check_deployment_status(tool, target)
            
            # デプロイ実行（実際の実装では各ツールのデプロイコマンドを実行）
            deploy_result = self._simulate_deployment(tool, target)
            
            # デプロイ後の状態確認
            post_deploy_status = self._check_deployment_status(tool, target)
            
            end_time = time.time()
            deployment_duration = end_time - start_time
            
            results[target] = {
                "duration_seconds": deployment_duration,
                "pre_deploy_status": pre_deploy_status,
                "post_deploy_status": post_deploy_status,
                "deploy_result": deploy_result,
                "success": deploy_result.get("success", False)
            }
            
            print(f"{target.upper()}デプロイ時間: {deployment_duration:.2f}秒")
        
        return results
    
    def _check_deployment_status(self, tool: str, target: str) -> Dict:
        """デプロイメント状態をチェック"""
        try:
            if target == "lambda":
                url = self.endpoints[tool]["lambda_url"]
            else:
                url = self.endpoints[tool]["alb_url"]
            
            response = requests.get(f"{url}/health", timeout=10)
            
            return {
                "accessible": response.status_code == 200,
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds(),
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                "accessible": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
    
    def _simulate_deployment(self, tool: str, target: str) -> Dict:
        """デプロイメントをシミュレート（実際の実装では実際のデプロイコマンドを実行）"""
        # 実際の実装では、各ツールの実際のデプロイコマンドを実行
        # ここではシミュレーションとして短時間待機
        time.sleep(2)  # デプロイ時間をシミュレート
        
        return {
            "success": True,
            "target": target,
            "tool": tool,
            "simulated": True
        }
    
    def generate_comparison_report(self, results: List[Dict]) -> Dict:
        """
        比較レポートを生成
        
        Args:
            results: 各ツールの測定結果リスト
            
        Returns:
            比較レポート
        """
        report = {
            "generated_at": datetime.now().isoformat(),
            "tools_compared": len(results),
            "individual_results": results,
            "comparison_summary": {}
        }
        
        # 実行時間比較
        execution_times = {}
        deployment_speeds = {}
        
        for result in results:
            tool = result["tool"]
            
            if "total_duration_seconds" in result:
                execution_times[tool] = result["total_duration_seconds"]
            
            if "deployment_results" in result:
                deployment_speeds[tool] = result["deployment_results"]
        
        # 最速・最遅ツールの特定
        if execution_times:
            fastest_tool = min(execution_times, key=execution_times.get)
            slowest_tool = max(execution_times, key=execution_times.get)
            
            report["comparison_summary"]["execution_time"] = {
                "fastest": {
                    "tool": fastest_tool,
                    "time_seconds": execution_times[fastest_tool]
                },
                "slowest": {
                    "tool": slowest_tool,
                    "time_seconds": execution_times[slowest_tool]
                },
                "time_difference_seconds": execution_times[slowest_tool] - execution_times[fastest_tool]
            }
        
        # 成功率の計算
        success_rates = {}
        for result in results:
            tool = result["tool"]
            success_rates[tool] = 1.0 if result.get("status") == "success" else 0.0
        
        report["comparison_summary"]["success_rates"] = success_rates
        
        return report
    
    def save_results(self, results: Dict, filename: str = None):
        """結果をJSONファイルに保存"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"cicd_performance_comparison_{timestamp}.json"
        
        output_path = Path("reports") / filename
        output_path.parent.mkdir(exist_ok=True)
        
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        print(f"\n結果を保存しました: {output_path}")
        return output_path


def main():
    """メイン実行関数"""
    parser = argparse.ArgumentParser(description="CI/CDツールパフォーマンス比較")
    parser.add_argument("--tools", nargs="+", choices=["github", "gitlab", "codepipeline"], 
                       default=["github", "gitlab", "codepipeline"],
                       help="比較するCI/CDツール")
    parser.add_argument("--measure-deployment", action="store_true",
                       help="デプロイ速度も測定する")
    parser.add_argument("--output", type=str,
                       help="出力ファイル名")
    
    args = parser.parse_args()
    
    analyzer = CICDPerformanceAnalyzer()
    all_results = []
    
    print("CI/CDツールパフォーマンス比較を開始します...")
    print(f"対象ツール: {', '.join(args.tools)}")
    
    for tool in args.tools:
        print(f"\n{'='*50}")
        print(f"{analyzer.endpoints[tool]['name']} の測定を開始")
        print(f"{'='*50}")
        
        # パイプライン実行時間測定
        pipeline_result = analyzer.measure_pipeline_execution_time(tool)
        
        # デプロイ速度測定（オプション）
        if args.measure_deployment:
            deployment_result = analyzer.measure_deployment_speed(tool)
            pipeline_result["deployment_results"] = deployment_result
        
        all_results.append(pipeline_result)
    
    # 比較レポート生成
    comparison_report = analyzer.generate_comparison_report(all_results)
    
    # 結果保存
    output_path = analyzer.save_results(comparison_report, args.output)
    
    # サマリー表示
    print(f"\n{'='*50}")
    print("比較結果サマリー")
    print(f"{'='*50}")
    
    if "execution_time" in comparison_report["comparison_summary"]:
        exec_summary = comparison_report["comparison_summary"]["execution_time"]
        print(f"最速ツール: {exec_summary['fastest']['tool']} ({exec_summary['fastest']['time_seconds']:.2f}秒)")
        print(f"最遅ツール: {exec_summary['slowest']['tool']} ({exec_summary['slowest']['time_seconds']:.2f}秒)")
        print(f"時間差: {exec_summary['time_difference_seconds']:.2f}秒")
    
    success_rates = comparison_report["comparison_summary"]["success_rates"]
    print(f"\n成功率:")
    for tool, rate in success_rates.items():
        print(f"  {tool}: {rate*100:.1f}%")
    
    print(f"\n詳細レポート: {output_path}")


if __name__ == "__main__":
    main()
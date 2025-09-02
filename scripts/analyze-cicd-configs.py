#!/usr/bin/env python3
"""
CI/CD設定ファイルの記述量と複雑さを比較する分析スクリプト

各CI/CDツールの設定ファイル（YAML）を解析し、
記述量、複雑さ、機能の違いを定量的に比較する。
"""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass
class ConfigAnalysis:
    """設定ファイル分析結果"""

    tool_name: str
    file_path: str
    line_count: int
    yaml_nodes: int
    job_count: int
    step_count: int
    dependency_count: int
    secret_count: int
    cache_usage: bool
    parallel_jobs: int
    complexity_score: float
    features: list[str]


class CICDConfigAnalyzer:
    """CI/CD設定ファイル分析器"""

    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root)

        # 各CI/CDツールの設定ファイルパス
        self.config_files = {
            "GitHub Actions": self.project_root / ".github" / "workflows" / "ci.yml",
            "GitLab CI/CD": self.project_root / ".gitlab-ci.yml",
            "CodePipeline": self.project_root / "cdk" / "lib" / "pipeline-stack.ts",
        }

        # buildspecファイルも含める
        self.buildspec_dir = self.project_root / "codepipeline" / "buildspecs"

    def analyze_file_metrics(self, file_path: Path) -> dict[str, Any]:
        """ファイルの基本メトリクスを分析"""
        if not file_path.exists():
            return {"exists": False}

        with open(file_path, encoding="utf-8") as f:
            content = f.read()

        lines = content.split("\n")
        non_empty_lines = [line for line in lines if line.strip()]
        comment_lines = [line for line in lines if line.strip().startswith("#")]

        return {
            "exists": True,
            "total_lines": len(lines),
            "non_empty_lines": len(non_empty_lines),
            "comment_lines": len(comment_lines),
            "code_lines": len(non_empty_lines) - len(comment_lines),
            "file_size": len(content),
            "content": content,
        }

    def analyze_yaml_structure(self, content: str) -> dict[str, Any]:
        """YAML構造を分析"""
        try:
            yaml_data = yaml.safe_load(content)
            if not yaml_data:
                return {"valid_yaml": False}

            def count_nodes(obj, depth=0):
                """YAML ノード数を再帰的にカウント"""
                if isinstance(obj, dict):
                    return 1 + sum(count_nodes(v, depth + 1) for v in obj.values())
                elif isinstance(obj, list):
                    return 1 + sum(count_nodes(item, depth + 1) for item in obj)
                else:
                    return 1

            def max_depth(obj, current_depth=0):
                """最大ネスト深度を計算"""
                if isinstance(obj, dict):
                    return max(
                        [max_depth(v, current_depth + 1) for v in obj.values()]
                        + [current_depth]
                    )
                elif isinstance(obj, list):
                    return max(
                        [max_depth(item, current_depth + 1) for item in obj]
                        + [current_depth]
                    )
                else:
                    return current_depth

            return {
                "valid_yaml": True,
                "yaml_data": yaml_data,
                "node_count": count_nodes(yaml_data),
                "max_depth": max_depth(yaml_data),
                "top_level_keys": len(yaml_data) if isinstance(yaml_data, dict) else 0,
            }

        except yaml.YAMLError as e:
            return {"valid_yaml": False, "error": str(e)}

    def analyze_github_actions(self, content: str, yaml_data: dict) -> dict[str, Any]:
        """GitHub Actions固有の分析"""
        analysis = {
            "jobs": {},
            "job_count": 0,
            "step_count": 0,
            "parallel_jobs": 0,
            "features": [],
        }

        if "jobs" in yaml_data:
            analysis["job_count"] = len(yaml_data["jobs"])
            analysis["parallel_jobs"] = len(
                yaml_data["jobs"]
            )  # GitHub Actionsは基本的に並列実行

            total_steps = 0
            for job_name, job_config in yaml_data["jobs"].items():
                if isinstance(job_config, dict) and "steps" in job_config:
                    step_count = len(job_config["steps"])
                    total_steps += step_count
                    analysis["jobs"][job_name] = {"steps": step_count}

            analysis["step_count"] = total_steps

        # 機能の検出
        if "strategy" in content:
            analysis["features"].append("matrix_strategy")
        if "cache" in content or "actions/cache" in content:
            analysis["features"].append("caching")
        if "secrets." in content:
            analysis["features"].append("secrets_usage")
        if "needs:" in content:
            analysis["features"].append("job_dependencies")
        if "if:" in content:
            analysis["features"].append("conditional_execution")
        if "OIDC" in content or "id-token" in content:
            analysis["features"].append("oidc_authentication")

        return analysis

    def analyze_gitlab_ci(self, content: str, yaml_data: dict) -> dict[str, Any]:
        """GitLab CI/CD固有の分析"""
        analysis = {
            "stages": [],
            "jobs": {},
            "job_count": 0,
            "step_count": 0,
            "parallel_jobs": 0,
            "features": [],
        }

        # ステージの分析
        if "stages" in yaml_data:
            analysis["stages"] = yaml_data["stages"]

        # ジョブの分析
        jobs = {
            k: v
            for k, v in yaml_data.items()
            if isinstance(v, dict)
            and k
            not in ["stages", "variables", "cache", "before_script", "after_script"]
        }

        analysis["job_count"] = len(jobs)

        # 並列ジョブの計算（同じステージ内のジョブ数）
        stage_jobs = {}
        for _job_name, job_config in jobs.items():
            stage = job_config.get("stage", "test")  # デフォルトステージ
            if stage not in stage_jobs:
                stage_jobs[stage] = 0
            stage_jobs[stage] += 1

        analysis["parallel_jobs"] = max(stage_jobs.values()) if stage_jobs else 0

        # スクリプトステップの計算
        total_steps = 0
        for job_name, job_config in jobs.items():
            steps = 0
            if "script" in job_config:
                if isinstance(job_config["script"], list):
                    steps = len(job_config["script"])
                else:
                    steps = 1
            if "before_script" in job_config:
                if isinstance(job_config["before_script"], list):
                    steps += len(job_config["before_script"])
                else:
                    steps += 1
            if "after_script" in job_config:
                if isinstance(job_config["after_script"], list):
                    steps += len(job_config["after_script"])
                else:
                    steps += 1

            total_steps += steps
            analysis["jobs"][job_name] = {"steps": steps}

        analysis["step_count"] = total_steps

        # 機能の検出
        if "cache:" in content:
            analysis["features"].append("caching")
        if "variables:" in content:
            analysis["features"].append("variables")
        if "needs:" in content:
            analysis["features"].append("job_dependencies")
        if "rules:" in content or "only:" in content or "except:" in content:
            analysis["features"].append("conditional_execution")
        if "parallel:" in content:
            analysis["features"].append("parallel_execution")
        if "artifacts:" in content:
            analysis["features"].append("artifacts")

        return analysis

    def analyze_codepipeline_buildspecs(self) -> dict[str, Any]:
        """CodePipeline buildspecファイル群の分析"""
        analysis = {
            "buildspec_files": [],
            "total_buildspecs": 0,
            "job_count": 0,  # buildspecファイル数をジョブ数とする
            "step_count": 0,
            "parallel_jobs": 0,
            "features": [],
        }

        if not self.buildspec_dir.exists():
            return analysis

        buildspec_files = list(self.buildspec_dir.glob("*.yml")) + list(
            self.buildspec_dir.glob("*.yaml")
        )
        analysis["total_buildspecs"] = len(buildspec_files)
        analysis["job_count"] = len(buildspec_files)  # 各buildspecを1ジョブとして計算
        analysis["parallel_jobs"] = len(buildspec_files)  # CodePipelineでは並列実行可能

        total_steps = 0

        for buildspec_file in buildspec_files:
            file_analysis = self.analyze_file_metrics(buildspec_file)
            if not file_analysis["exists"]:
                continue

            yaml_analysis = self.analyze_yaml_structure(file_analysis["content"])
            if not yaml_analysis["valid_yaml"]:
                continue

            buildspec_data = yaml_analysis["yaml_data"]

            # フェーズ内のコマンド数をステップ数として計算
            phases = buildspec_data.get("phases", {})
            file_steps = 0

            for _phase_name, phase_config in phases.items():
                if isinstance(phase_config, dict) and "commands" in phase_config:
                    commands = phase_config["commands"]
                    if isinstance(commands, list):
                        file_steps += len(commands)
                    else:
                        file_steps += 1

            total_steps += file_steps

            analysis["buildspec_files"].append(
                {
                    "file": buildspec_file.name,
                    "steps": file_steps,
                    "phases": list(phases.keys()) if phases else [],
                }
            )

            # 機能の検出
            content = file_analysis["content"]
            if "cache:" in content:
                analysis["features"].append("caching")
            if "artifacts:" in content:
                analysis["features"].append("artifacts")
            if "reports:" in content:
                analysis["features"].append("test_reports")

        analysis["step_count"] = total_steps

        # 重複する機能を除去
        analysis["features"] = list(set(analysis["features"]))

        return analysis

    def calculate_complexity_score(
        self, metrics: dict[str, Any], tool_specific: dict[str, Any]
    ) -> float:
        """複雑さスコアを計算"""
        # 基本メトリクス（重み付き）
        base_score = (
            metrics.get("code_lines", 0) * 0.1  # コード行数
            + metrics.get("node_count", 0) * 0.2  # YAMLノード数
            + tool_specific.get("job_count", 0) * 2.0  # ジョブ数
            + tool_specific.get("step_count", 0) * 0.5  # ステップ数
            + len(tool_specific.get("features", [])) * 1.0  # 機能数
        )

        # 並列度による調整（並列度が高いほど複雑）
        parallel_factor = 1.0 + (tool_specific.get("parallel_jobs", 0) * 0.1)

        return base_score * parallel_factor

    def analyze_all_configs(self) -> list[ConfigAnalysis]:
        """全CI/CD設定ファイルを分析"""
        results = []

        # GitHub Actions
        gh_file = self.config_files["GitHub Actions"]
        if gh_file.exists():
            metrics = self.analyze_file_metrics(gh_file)
            yaml_analysis = self.analyze_yaml_structure(metrics["content"])

            if yaml_analysis["valid_yaml"]:
                gh_specific = self.analyze_github_actions(
                    metrics["content"], yaml_analysis["yaml_data"]
                )

                complexity = self.calculate_complexity_score(
                    {**metrics, **yaml_analysis}, gh_specific
                )

                results.append(
                    ConfigAnalysis(
                        tool_name="GitHub Actions",
                        file_path=str(gh_file),
                        line_count=metrics["code_lines"],
                        yaml_nodes=yaml_analysis["node_count"],
                        job_count=gh_specific["job_count"],
                        step_count=gh_specific["step_count"],
                        dependency_count=metrics["content"].count("needs:"),
                        secret_count=metrics["content"].count("secrets."),
                        cache_usage="caching" in gh_specific["features"],
                        parallel_jobs=gh_specific["parallel_jobs"],
                        complexity_score=complexity,
                        features=gh_specific["features"],
                    )
                )

        # GitLab CI/CD
        gl_file = self.config_files["GitLab CI/CD"]
        if gl_file.exists():
            metrics = self.analyze_file_metrics(gl_file)
            yaml_analysis = self.analyze_yaml_structure(metrics["content"])

            if yaml_analysis["valid_yaml"]:
                gl_specific = self.analyze_gitlab_ci(
                    metrics["content"], yaml_analysis["yaml_data"]
                )

                complexity = self.calculate_complexity_score(
                    {**metrics, **yaml_analysis}, gl_specific
                )

                results.append(
                    ConfigAnalysis(
                        tool_name="GitLab CI/CD",
                        file_path=str(gl_file),
                        line_count=metrics["code_lines"],
                        yaml_nodes=yaml_analysis["node_count"],
                        job_count=gl_specific["job_count"],
                        step_count=gl_specific["step_count"],
                        dependency_count=metrics["content"].count("needs:"),
                        secret_count=metrics["content"].count("$"),  # GitLabの変数参照
                        cache_usage="caching" in gl_specific["features"],
                        parallel_jobs=gl_specific["parallel_jobs"],
                        complexity_score=complexity,
                        features=gl_specific["features"],
                    )
                )

        # CodePipeline (buildspecファイル群)
        cp_analysis = self.analyze_codepipeline_buildspecs()
        if cp_analysis["total_buildspecs"] > 0:
            # 全buildspecファイルの合計行数を計算
            total_lines = 0
            total_nodes = 0

            for buildspec_file in self.buildspec_dir.glob("*.yml"):
                if buildspec_file.exists():
                    metrics = self.analyze_file_metrics(buildspec_file)
                    yaml_analysis = self.analyze_yaml_structure(metrics["content"])
                    total_lines += metrics.get("code_lines", 0)
                    total_nodes += yaml_analysis.get("node_count", 0)

            complexity = self.calculate_complexity_score(
                {"code_lines": total_lines, "node_count": total_nodes}, cp_analysis
            )

            results.append(
                ConfigAnalysis(
                    tool_name="CodePipeline",
                    file_path=str(self.buildspec_dir),
                    line_count=total_lines,
                    yaml_nodes=total_nodes,
                    job_count=cp_analysis["job_count"],
                    step_count=cp_analysis["step_count"],
                    dependency_count=0,  # buildspecファイル間の依存関係は外部で管理
                    secret_count=0,  # 環境変数として管理
                    cache_usage="caching" in cp_analysis["features"],
                    parallel_jobs=cp_analysis["parallel_jobs"],
                    complexity_score=complexity,
                    features=cp_analysis["features"],
                )
            )

        return results

    def generate_comparison_report(self, analyses: list[ConfigAnalysis]) -> str:
        """比較レポートを生成"""
        if not analyses:
            return "No CI/CD configurations found for analysis."

        report = []
        report.append("# CI/CD設定ファイル比較分析レポート")
        report.append("")
        report.append(
            f"分析日時: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        )
        report.append("")

        # サマリーテーブル
        report.append("## 概要比較")
        report.append("")
        report.append(
            "| ツール | ファイル数 | コード行数 | ジョブ数 | ステップ数 | 並列ジョブ数 | 複雑さスコア |"
        )
        report.append(
            "|--------|------------|------------|----------|------------|--------------|--------------|"
        )

        for analysis in analyses:
            file_count = (
                1
                if analysis.tool_name != "CodePipeline"
                else len(list(self.buildspec_dir.glob("*.yml")))
            )
            report.append(
                f"| {analysis.tool_name} | {file_count} | {analysis.line_count} | {analysis.job_count} | {analysis.step_count} | {analysis.parallel_jobs} | {analysis.complexity_score:.1f} |"
            )

        report.append("")

        # 詳細分析
        report.append("## 詳細分析")
        report.append("")

        for analysis in analyses:
            report.append(f"### {analysis.tool_name}")
            report.append("")
            report.append(f"- **設定ファイル**: `{analysis.file_path}`")
            report.append(f"- **コード行数**: {analysis.line_count}")
            report.append(f"- **YAMLノード数**: {analysis.yaml_nodes}")
            report.append(f"- **ジョブ数**: {analysis.job_count}")
            report.append(f"- **ステップ数**: {analysis.step_count}")
            report.append(f"- **並列ジョブ数**: {analysis.parallel_jobs}")
            report.append(f"- **依存関係数**: {analysis.dependency_count}")
            report.append(f"- **シークレット使用数**: {analysis.secret_count}")
            report.append(
                f"- **キャッシュ使用**: {'✓' if analysis.cache_usage else '✗'}"
            )
            report.append(f"- **複雑さスコア**: {analysis.complexity_score:.1f}")
            report.append(
                f"- **機能**: {', '.join(analysis.features) if analysis.features else 'なし'}"
            )
            report.append("")

        # 比較考察
        report.append("## 比較考察")
        report.append("")

        # 最も複雑/シンプルなツール
        most_complex = max(analyses, key=lambda x: x.complexity_score)
        least_complex = min(analyses, key=lambda x: x.complexity_score)

        report.append(
            f"- **最も複雑**: {most_complex.tool_name} (スコア: {most_complex.complexity_score:.1f})"
        )
        report.append(
            f"- **最もシンプル**: {least_complex.tool_name} (スコア: {least_complex.complexity_score:.1f})"
        )
        report.append("")

        # 行数比較
        max_lines = max(analyses, key=lambda x: x.line_count)
        min_lines = min(analyses, key=lambda x: x.line_count)

        report.append(
            f"- **最も記述量が多い**: {max_lines.tool_name} ({max_lines.line_count}行)"
        )
        report.append(
            f"- **最も記述量が少ない**: {min_lines.tool_name} ({min_lines.line_count}行)"
        )
        report.append("")

        # 並列度比較
        max_parallel = max(analyses, key=lambda x: x.parallel_jobs)

        report.append(
            f"- **最も並列度が高い**: {max_parallel.tool_name} ({max_parallel.parallel_jobs}並列ジョブ)"
        )
        report.append("")

        # 機能比較
        all_features = set()
        for analysis in analyses:
            all_features.update(analysis.features)

        if all_features:
            report.append("### 機能比較")
            report.append("")
            report.append(
                "| 機能 | " + " | ".join([a.tool_name for a in analyses]) + " |"
            )
            report.append("|------|" + "|".join(["------" for _ in analyses]) + "|")

            for feature in sorted(all_features):
                row = f"| {feature} |"
                for analysis in analyses:
                    has_feature = "✓" if feature in analysis.features else "✗"
                    row += f" {has_feature} |"
                report.append(row)

            report.append("")

        return "\n".join(report)

    def save_analysis_results(
        self, analyses: list[ConfigAnalysis], output_dir: str = "docs"
    ):
        """分析結果をファイルに保存"""
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)

        # JSON形式で詳細データを保存
        json_data = []
        for analysis in analyses:
            json_data.append(
                {
                    "tool_name": analysis.tool_name,
                    "file_path": analysis.file_path,
                    "metrics": {
                        "line_count": analysis.line_count,
                        "yaml_nodes": analysis.yaml_nodes,
                        "job_count": analysis.job_count,
                        "step_count": analysis.step_count,
                        "dependency_count": analysis.dependency_count,
                        "secret_count": analysis.secret_count,
                        "parallel_jobs": analysis.parallel_jobs,
                        "complexity_score": analysis.complexity_score,
                    },
                    "features": {
                        "cache_usage": analysis.cache_usage,
                        "feature_list": analysis.features,
                    },
                }
            )

        json_file = output_path / "cicd-config-analysis.json"
        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(json_data, f, indent=2, ensure_ascii=False)

        # Markdownレポートを保存
        report = self.generate_comparison_report(analyses)
        md_file = output_path / "cicd-config-comparison.md"
        with open(md_file, "w", encoding="utf-8") as f:
            f.write(report)

        print("分析結果を保存しました:")
        print(f"- 詳細データ: {json_file}")
        print(f"- 比較レポート: {md_file}")


def main():
    """メイン実行関数"""
    import argparse

    parser = argparse.ArgumentParser(description="CI/CD設定ファイルの比較分析")
    parser.add_argument(
        "--project-root", default=".", help="プロジェクトルートディレクトリ"
    )
    parser.add_argument("--output-dir", default="docs", help="出力ディレクトリ")
    parser.add_argument(
        "--format", choices=["console", "file", "both"], default="both", help="出力形式"
    )

    args = parser.parse_args()

    analyzer = CICDConfigAnalyzer(args.project_root)
    analyses = analyzer.analyze_all_configs()

    if not analyses:
        print("CI/CD設定ファイルが見つかりませんでした。")
        return

    if args.format in ["console", "both"]:
        report = analyzer.generate_comparison_report(analyses)
        print(report)

    if args.format in ["file", "both"]:
        analyzer.save_analysis_results(analyses, args.output_dir)


if __name__ == "__main__":
    main()

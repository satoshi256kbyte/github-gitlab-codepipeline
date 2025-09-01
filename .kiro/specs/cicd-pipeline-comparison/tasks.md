# 実装計画

- [x] 1. プロジェクト基盤の構築
  - プロジェクトディレクトリ構造を作成し、基本的な設定ファイルを配置する
  - asdfによるランタイムバージョン管理設定を作成する
  - uvによるPython依存関係管理の初期設定を行う
  - _要件: 1.3, 6.3_

- [x] 2. FastAPIアプリケーションの実装
- [x] 2.1 FastAPIアプリケーションのコア実装
  - FastAPIアプリケーションのメインファイル（main.py）を作成する
  - 基本的なFastAPI設定とCORS設定を実装する
  - アプリケーション設定管理クラスを実装する
  - _要件: 1.1_

- [x] 2.2 APIエンドポイントの実装
  - ヘルスチェックエンドポイント（/health）を実装する
  - バージョン情報エンドポイント（/version）を実装する
  - アイテムCRUDエンドポイント（/api/items）を実装する
  - エラーハンドリングとレスポンスモデルを実装する
  - _要件: 1.2_

- [x] 2.3 データモデルとバリデーションの実装
  - Pydanticモデル（Item, ItemCreate, HealthResponse等）を実装する
  - 入力データのバリデーション機能を実装する
  - レスポンスデータの構造化を実装する
  - _要件: 1.2_

- [x] 3. ユニットテストの実装
- [x] 3.1 テスト環境の構築
  - pytestの設定ファイル（pytest.ini, conftest.py）を作成する
  - テストディレクトリ構造を作成する
  - テスト用のモックとフィクスチャを実装する
  - _要件: 1.4_

- [x] 3.2 APIエンドポイントのテスト実装
  - ヘルスチェックエンドポイントのテストを実装する
  - バージョン情報エンドポイントのテストを実装する
  - アイテムCRUDエンドポイントのテストを実装する
  - エラーケースのテストを実装する
  - _要件: 1.4_

- [x] 4. AWS CDKインフラストラクチャの実装
- [x] 4.1 CDKプロジェクトの初期化
  - AWS CDKプロジェクトを初期化する（TypeScript）
  - 基本的なCDK設定とスタック構造を定義する
  - 環境設定（local環境）とリソース命名規約を実装する
  - _要件: 5.1, 5.4_

- [x] 4.2 ネットワークインフラの実装
  - VPC、サブネット、インターネットゲートウェイを作成する
  - セキュリティグループとNACLを設定する
  - NAT Gatewayとルートテーブルを設定する
  - _要件: 5.1_

- [x] 4.3 パラメータ化されたLambda + API Gatewayインフラの実装
  - CI/CDツール名をパラメータとして受け取る再利用可能なLambdaスタッククラスを作成する
  - {cicdTool}-local-lambda-*という命名規約でAPI Gateway REST APIとLambda統合を設定する
  - 3つのCI/CDツール（github, gitlab, codepipeline）用にスタックをインスタンス化する
  - Lambda関数用のIAMロール（Admin権限）をパラメータ化して作成する
  - _要件: 5.1, 5.5_

- [x] 4.4 パラメータ化されたECSインフラの実装
  - CI/CDツール名とポート番号をパラメータとして受け取る再利用可能なECSスタッククラスを作成する
  - {cicdTool}-local-ecs-*という命名規約でECSクラスター（Fargate）を作成する
  - ポート番号（8080, 8081, 8082）を使い分けてApplication Load Balancerとターゲットグループを設定する
  - 3つのCI/CDツール用にスタックをインスタンス化する
  - Blue/Greenデプロイメント設定をパラメータ化して実装する
  - _要件: 5.1, 5.5_

- [x] 4.5 パラメータ化されたEC2インフラの実装
  - CI/CDツール名とポート番号をパラメータとして受け取る再利用可能なEC2スタッククラスを作成する
  - {cicdTool}-local-ec2-*という命名規約でEC2インスタンス（t4g.micro）とAuto Scaling Groupを作成する
  - ポート番号（8080, 8081, 8082）を使い分けてApplication Load Balancerとターゲットグループを設定する
  - 3つのCI/CDツール用にスタックをインスタンス化する
  - CodeDeployアプリケーションとデプロイメントグループをパラメータ化して作成する
  - Blue/Greenデプロイメント用の設定をパラメータ化して実装する
  - _要件: 5.1, 5.2, 5.5_

- [x] 5. GitHub Actionsパイプラインの実装
- [x] 5.1 GitHub Actions基本設定
  - GitHub Actionsワークフローファイル（ci.yml）を作成する
  - 並列実行ジョブの基本構造を定義する
  - 環境変数とシークレット管理を設定する
  - _要件: 2.1_

- [x] 5.2 チェック工程の実装（GitHub Actions）
  - 静的解析ジョブ（ruff, black）を実装する
  - ユニットテストジョブ（pytest）を実装する
  - SCAチェックジョブ（Dependabot + CodeGuru Security）を実装する
  - SASTチェックジョブ（CodeQL + CodeGuru Security）を実装する
  - _要件: 2.1, 2.3, 2.4, 2.7_

- [x] 5.3 デプロイ工程の実装（GitHub Actions）
  - GitHub Actions専用リソース（github-local-*）へのAWS SAMによるLambdaデプロイジョブを実装する
  - GitHub Actions専用リソース（github-local-ecs-*）へのECS Blue/Greenデプロイジョブを実装する
  - GitHub Actions専用リソース（github-local-ec2-*）へのEC2 CodeDeploy Blue/Greenデプロイジョブを実装する
  - _要件: 2.2, 2.5, 2.6_

- [x] 5.4 GitHub OIDC認証の設定
  - GitHub OIDC Provider用のIAMロールを作成する（オプション）
  - GitHub ActionsでのAWS認証設定を実装する
  - _要件: 5.6_

- [x] 6. GitLab CI/CDパイプラインの実装
- [x] 6.1 GitLab CI/CD基本設定
  - GitLab CI/CDパイプラインファイル（.gitlab-ci.yml）を作成する
  - ステージとジョブの基本構造を定義する
  - 変数とキャッシュ設定を実装する
  - _要件: 3.1_

- [x] 6.2 チェック工程の実装（GitLab CI/CD）
  - 静的解析ジョブを実装する
  - ユニットテストジョブを実装する
  - SCAチェックジョブ（GitLab Dependency Scanning + CodeGuru Security）を実装する
  - SASTチェックジョブ（GitLab SAST + CodeGuru Security）を実装する
  - _要件: 3.1, 3.3, 3.4, 3.7_

- [x] 6.3 デプロイ工程の実装（GitLab CI/CD）
  - GitLab CI/CD専用リソース（gitlab-local-*）へのAWS SAMによるLambdaデプロイジョブを実装する
  - GitLab CI/CD専用リソース（gitlab-local-ecs-*）へのECS Blue/Greenデプロイジョブを実装する
  - GitLab CI/CD専用リソース（gitlab-local-ec2-*）へのEC2 CodeDeploy Blue/Greenデプロイジョブを実装する
  - _要件: 3.2, 3.5, 3.6_

- [x] 7. AWS CodePipelineパイプラインの実装
- [x] 7.1 CodePipeline基本設定
  - CodePipelineパイプラインをCDKで定義する
  - ソースステージ（GitHub連携）を設定する
  - 基本的なパイプライン構造を実装する
  - _要件: 4.1_

- [x] 7.2 CodeBuildプロジェクトの実装
  - キャッシュ作成用のCodeBuildプロジェクトを作成する
  - 静的解析用のCodeBuildプロジェクトを作成する
  - ユニットテスト用のCodeBuildプロジェクトを作成する
  - SCAチェック用のCodeBuildプロジェクト（CodeGuru Security）を作成する
  - SASTチェック用のCodeBuildプロジェクト（Amazon Inspector）を作成する
  - _要件: 4.1, 4.3, 4.4, 4.7_

- [x] 7.3 buildspecファイルの実装
  - 共通スクリプト（common_install.sh, common_pre_build.sh）を作成する
  - 各チェック工程用のbuildspecファイルを作成する
  - CodePipeline専用リソース用のデプロイ工程buildspecファイルを作成する
  - _要件: 4.1_

- [x] 7.4 デプロイステージの実装
  - CodePipeline専用リソース（codepipeline-local-*）へのAWS SAMによるLambdaデプロイステージを実装する
  - CodePipeline専用リソース（codepipeline-local-ecs-*）へのECS Blue/Greenデプロイステージを実装する
  - CodePipeline専用リソース（codepipeline-local-ec2-*）へのEC2 CodeDeploy Blue/Greenデプロイステージを実装する
  - _要件: 4.2, 4.5, 4.6_

- [x] 8. ローカルテスト環境の構築
- [x] 8.1 GitHub Actionsローカルテスト環境
  - actツールのインストールと設定を行う
  - .actrcファイルでローカル実行設定を作成する
  - ローカルでのGitHub Actionsテスト手順を文書化する
  - _要件: 6.1_

- [x] 8.2 GitLab CI/CDローカルテスト環境
  - GitLab Runnerのローカルインストールと設定を行う
  - .gitlab-runner/config.tomlでローカル実行設定を作成する
  - ローカルでのGitLab CI/CDテスト手順を文書化する
  - _要件: 6.2_

- [x] 9. デプロイメント設定ファイルの実装
- [x] 9.1 AWS SAM設定
  - 各CI/CDツール専用リソース用のパラメータ化されたSAMテンプレート（template.yaml）を作成する
  - Lambda関数のパッケージング設定を実装する
  - 各CI/CDツール専用のAPI Gatewayとの統合設定を実装する
  - _要件: 2.2, 3.2, 4.2_

- [x] 9.2 ECS Blue/Greenデプロイ設定
  - 各CI/CDツール専用リソース用のECSタスク定義ファイル（taskdef.json）を作成する
  - 各CI/CDツール専用のappspec.ymlファイルを作成する
  - 共通のDockerfileとコンテナイメージビルド設定を実装する
  - _要件: 2.5, 3.5, 4.5_

- [x] 9.3 EC2 CodeDeploy設定
  - 各CI/CDツール専用リソース用のCodeDeploy用appspec.ymlファイルを作成する
  - 共通のアプリケーション起動・停止スクリプトを作成する
  - 各CI/CDツール専用のEC2インスタンス用ユーザーデータスクリプトを作成する
  - _要件: 2.6, 3.6, 4.6_

- [x] 10. ログ管理とモニタリングの実装
- [x] 10.1 CloudWatchログ設定
  - 各CI/CDツール専用のLambda関数用CloudWatchログ設定を実装する
  - 各CI/CDツール専用のECSタスク用CloudWatchログ設定を実装する
  - 各CI/CDツール専用のEC2アプリケーション用CloudWatchログ設定を実装する
  - CI/CDツール別にロググループを分離する設定を実装する
  - _要件: 8.1, 9.4_

- [x] 11. CI/CDツール比較機能の実装
- [x] 11.1 比較用エンドポイントアクセステストの実装
  - 各CI/CDツール専用エンドポイント（異なるポート）でのアクセステストを作成する
  - GitHub Actions用（Port 8080）、GitLab CI/CD用（Port 8081）、CodePipeline用（Port 8082）のヘルスチェック確認テストを作成する
  - 各ツール専用リソースでの基本的なCRUD操作の動作確認テストを作成する
  - _要件: 9.1, 9.3_

- [x] 11.2 パフォーマンス比較機能の実装
  - 各CI/CDツールのパイプライン実行時間を測定するスクリプトを作成する
  - 各ツールのデプロイ速度を比較するためのメトリクス収集機能を実装する
  - パイプライン失敗条件のテストケースを各ツール用に作成する
  - _要件: 7.1, 9.2_

- [x] 12. 統合テストとドキュメント
- [x] 12.1 統合テストの実装
  - 3つのCI/CDツールが同時実行されても相互に影響しないことを確認するテストを作成する
  - CI/CDツール別のCloudWatchロググループ分離を確認するテストを作成する
  - 各ツールの設定ファイル（YAML）の記述量と複雑さを比較する分析スクリプトを作成する
  - _要件: 9.1, 9.4, 9.5_

- [x] 12.2 ドキュメントの作成
  - README.mdでプロジェクト概要と3つのCI/CDツール比較の使用方法を文書化する
  - 各CI/CDツールの設定手順と専用リソースへのアクセス方法を文書化する
  - ローカルテスト環境の構築手順を文書化する
  - CI/CDツール比較結果の解釈方法とトラブルシューティングガイドを作成する
  - _要件: 全要件_

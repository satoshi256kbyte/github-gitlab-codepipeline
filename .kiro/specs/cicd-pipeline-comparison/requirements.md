# 要件定義書

## はじめに

GitHub Actions、GitLab CI/CD、AWS CodePipelineの3つのCI/CDツールでパイプラインを構築し、それぞれの書き方と挙動の違いを比較するためのサンプルシステムです。PythonのFastAPIアプリケーションを3つの異なるAWSデプロイ先（Lambda、ECS、EC2）にデプロイし、各ツールの特徴を実証します。

## 要件

### 要件1: FastAPIアプリケーションの開発

**ユーザーストーリー:** 開発者として、CI/CDパイプラインでデプロイするためのシンプルなFastAPIアプリケーションが欲しい。そうすることで、各CI/CDツールの動作を検証できる。

#### 受け入れ基準

1. WHEN FastAPIアプリケーションが作成される THEN Python 3.13とFastAPIを使用してRESTful APIを提供すること
2. WHEN APIエンドポイントにアクセスする THEN ヘルスチェック、バージョン情報、簡単なCRUD操作のエンドポイントが利用可能であること
3. WHEN アプリケーションが実行される THEN uvパッケージマネージャーで依存関係が管理されていること
4. WHEN テストが実行される THEN pytestによるユニットテストが含まれていること

### 要件2: GitHub Actionsパイプラインの実装

**ユーザーストーリー:** 開発者として、GitHub Actionsを使用したCI/CDパイプラインが欲しい。そうすることで、GitHubネイティブなワークフローでGitHub Actions専用のAWSリソースにアプリケーションをデプロイできる。

#### 受け入れ基準

1. WHEN コードがプッシュされる THEN 静的解析、ユニットテスト、SCAチェック、SASTチェックが並列実行されること
2. WHEN チェック工程が完了する THEN GitHub Actions専用のAWS Lambda、ECS、EC2への自動デプロイが実行されること
3. WHEN SCAチェックが実行される THEN GitHub DependabotとAWS CodeGuru Securityの両方が実行されること
4. WHEN SASTチェックが実行される THEN GitHub CodeQLとAWS CodeGuru Securityの両方が実行されること
5. WHEN ECSデプロイが実行される THEN github-local-ecs-*リソースへのBlue/Greenデプロイメントが実行されること
6. WHEN EC2デプロイが実行される THEN github-local-ec2-*リソースへのAWS CodeDeployによるBlue/Greenデプロイメントが実行されること
7. WHEN チェック工程で問題が検出される THEN 静的解析失敗、ユニットテスト失敗、SCA脆弱性発見、SAST脆弱性発見のいずれかでパイプラインが失敗すること

### 要件3: GitLab CI/CDパイプラインの実装

**ユーザーストーリー:** 開発者として、GitLab CI/CDを使用したCI/CDパイプラインが欲しい。そうすることで、GitLabネイティブなワークフローでGitLab CI/CD専用のAWSリソースにアプリケーションをデプロイできる。

#### 受け入れ基準

1. WHEN コードがプッシュされる THEN 静的解析、ユニットテスト、SCAチェック、SASTチェックが並列実行されること
2. WHEN チェック工程が完了する THEN GitLab CI/CD専用のAWS Lambda、ECS、EC2への自動デプロイが実行されること
3. WHEN SCAチェックが実行される THEN GitLab Dependency ScanningとAWS CodeGuru Securityの両方が実行されること
4. WHEN SASTチェックが実行される THEN GitLab SASTとAWS CodeGuru Securityの両方が実行されること
5. WHEN ECSデプロイが実行される THEN gitlab-local-ecs-*リソースへのBlue/Greenデプロイメントが実行されること
6. WHEN EC2デプロイが実行される THEN gitlab-local-ec2-*リソースへのAWS CodeDeployによるBlue/Greenデプロイメントが実行されること
7. WHEN チェック工程で問題が検出される THEN 静的解析失敗、ユニットテスト失敗、SCA脆弱性発見、SAST脆弱性発見のいずれかでパイプラインが失敗すること

### 要件4: AWS CodePipelineパイプラインの実装

**ユーザーストーリー:** 開発者として、AWS CodePipelineを使用したCI/CDパイプラインが欲しい。そうすることで、AWSネイティブなワークフローでCodePipeline専用のAWSリソースにアプリケーションをデプロイできる。

#### 受け入れ基準

1. WHEN コードがプッシュされる THEN CodeBuildで静的解析、ユニットテスト、SCAチェック、SASTチェックが並列実行されること
2. WHEN チェック工程が完了する THEN CodePipeline専用のAWS Lambda、ECS、EC2への自動デプロイが実行されること
3. WHEN SCAチェックが実行される THEN AWS CodeGuru Securityが実行されること
4. WHEN SASTチェックが実行される THEN Amazon Inspectorが実行されること
5. WHEN ECSデプロイが実行される THEN codepipeline-local-ecs-*リソースへのBlue/Greenデプロイメントが実行されること
6. WHEN EC2デプロイが実行される THEN codepipeline-local-ec2-*リソースへのAWS CodeDeployによるBlue/Greenデプロイメントが実行されること
7. WHEN チェック工程で問題が検出される THEN 静的解析失敗、ユニットテスト失敗、SCA脆弱性発見、SAST脆弱性発見のいずれかでパイプラインが失敗すること

### 要件5: AWSインフラストラクチャの構築

**ユーザーストーリー:** 開発者として、AWS CDKで管理された各CI/CDツール専用のインフラストラクチャが欲しい。そうすることで、3つのCI/CDツールを同時に動かして違いを比較できる。

#### 受け入れ基準

1. WHEN インフラが構築される THEN AWS CDKで各CI/CDツール専用のLambda、ECS、EC2、ALB、VPCなどのリソースが定義されていること
2. WHEN EC2インスタンスが作成される THEN コスト効率のためt4g.microインスタンスタイプが各CI/CDツール用に3台使用されること
3. WHEN 環境が設定される THEN IaCで環境を選択可能だが、実際に作成するのはlocal環境のみであること
4. WHEN リソースが命名される THEN CI/CDツール別の統一された命名規約に従ってリソースが命名されること（github-local-*, gitlab-local-*, codepipeline-local-*）
5. WHEN 各CI/CDツールがデプロイする THEN 専用のAWSリソースにデプロイされ、他のCI/CDツールの影響を受けないこと
6. IF GitHub連携が有効化される THEN OIDC接続用のIAMロールが作成されること

### 要件6: ローカル開発・テスト環境の構築

**ユーザーストーリー:** 開発者として、ローカルでCI/CDパイプラインをテストできる環境が欲しい。そうすることで、実際のクラウド環境にデプロイする前に動作を確認できる。

#### 受け入れ基準

1. WHEN GitHub Actionsをローカルテストする THEN actツールが使用可能であること
2. WHEN GitLabパイプラインをローカルテストする THEN GitLab Runnerまたは類似ツールが使用可能であること
3. WHEN 依存関係が管理される THEN asdfを使用してランタイムバージョンが管理されていること

### 要件7: セキュリティとコンプライアンス

**ユーザーストーリー:** 開発者として、セキュリティベストプラクティスに従ったCI/CDパイプラインが欲しい。そうすることで、安全なアプリケーションデプロイメントが実現できる。

#### 受け入れ基準

1. WHEN パイプラインが実行される THEN 静的解析失敗、ユニットテスト失敗、SCAで脆弱性発見、SASTで脆弱性発見のいずれかが発生した場合パイプラインが失敗すること
2. WHEN コードが分析される THEN 静的解析ツールによってコード品質が保証されること

### 要件8: 基本的なログ管理

**ユーザーストーリー:** 開発者として、デプロイされたアプリケーションの基本的なログが欲しい。そうすることで、運用時の問題を確認できる。

#### 受け入れ基準

1. WHEN アプリケーションが実行される THEN CloudWatchでCI/CDツール別にログが収集されること

### 要件9: CI/CDツール比較機能

**ユーザーストーリー:** 開発者として、3つのCI/CDツールの違いを比較できる機能が欲しい。そうすることで、各ツールの特徴と適用場面を理解できる。

#### 受け入れ基準

1. WHEN 3つのCI/CDツールが同時実行される THEN それぞれが専用のAWSリソースにデプロイされ、相互に影響しないこと
2. WHEN パイプラインが実行される THEN 各ツールの実行時間とパフォーマンスが比較可能であること
3. WHEN デプロイが完了する THEN 各ツール専用のエンドポイント（異なるポート）でアプリケーションにアクセス可能であること
4. WHEN ログを確認する THEN CI/CDツール別にCloudWatchロググループが分離されていること
5. WHEN 設定を比較する THEN 各ツールのYAML設定ファイルの記述量と複雑さが比較可能であること

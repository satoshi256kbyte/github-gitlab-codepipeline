# AWS CodePipeline セットアップガイド

このドキュメントでは、AWS CodePipelineでCI/CDパイプラインを設定する手順を説明します。

## 📋 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [IAM設定](#iam設定)
- [CodePipeline設定](#codepipeline設定)
- [CodeBuild設定](#codebuild設定)
- [デプロイ設定](#デプロイ設定)
- [監視とログ](#監視とログ)
- [トラブルシューティング](#トラブルシューティング)

## 🎯 概要

AWS CodePipelineパイプラインは以下の特徴を持ちます：

- **AWSネイティブ**: 他のAWSサービスとのシームレスな連携
- **マネージドサービス**: インフラ管理不要
- **高度な並列実行**: 複数のCodeBuildプロジェクトを並列実行
- **統合セキュリティ**: CodeGuru Security、Amazon Inspectorとの連携

## 📋 前提条件

### 必要なサービス

- AWS アカウント
- AWS CLI v2
- 適切なIAM権限
- GitHub または GitLab リポジトリ

### 必要な権限

以下のAWSサービスへのアクセス権限が必要：

- CodePipeline
- CodeBuild
- CodeDeploy
- S3
- ECR
- ECS
- EC2
- Lambda
- IAM
- CloudWatch

## 🔐 IAM設定

### CodePipelineサービスロール

#### 信頼関係

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### 権限ポリシー

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::codepipeline-*",
        "arn:aws:s3:::codepipeline-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetApplication",
        "codedeploy:GetApplicationRevision",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:RegisterApplicationRevision"
      ],
      "Resource": "*"
    }
  ]
}
```

### CodeBuildサービスロール

#### 信頼関係

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### 権限ポリシー

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::codepipeline-*",
        "arn:aws:s3:::codepipeline-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codeguru-security:*",
        "inspector2:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🔄 CodePipeline設定

### CDKでのパイプライン定義

`cdk/lib/pipeline-stack.ts`：

```typescript
import * as cdk from 'aws-cdk-lib';
import * as codepipeline from 'aws-cdk-lib/aws-codepipeline';
import * as codepipeline_actions from 'aws-cdk-lib/aws-codepipeline-actions';
import * as codebuild from 'aws-cdk-lib/aws-codebuild';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';

export class PipelineStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // アーティファクト用S3バケット
    const artifactBucket = new s3.Bucket(this, 'ArtifactBucket', {
      bucketName: `cicd-comparison-artifacts-${this.account}`,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ソースアーティファクト
    const sourceOutput = new codepipeline.Artifact();
    const buildOutput = new codepipeline.Artifact();

    // CodeBuildプロジェクト
    const cacheProject = this.createCacheProject(artifactBucket);
    const lintProject = this.createLintProject(artifactBucket);
    const testProject = this.createTestProject(artifactBucket);
    const scaProject = this.createSCAProject(artifactBucket);
    const sastProject = this.createSASTProject(artifactBucket);

    // パイプライン
    const pipeline = new codepipeline.Pipeline(this, 'Pipeline', {
      pipelineName: 'cicd-comparison-pipeline',
      artifactBucket: artifactBucket,
      stages: [
        {
          stageName: 'Source',
          actions: [
            new codepipeline_actions.GitHubSourceAction({
              actionName: 'GitHub_Source',
              owner: 'your-username',
              repo: 'your-repo',
              branch: 'main',
              oauthToken: cdk.SecretValue.secretsManager('github-token'),
              output: sourceOutput,
            }),
          ],
        },
        {
          stageName: 'Cache',
          actions: [
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Create_Cache',
              project: cacheProject,
              input: sourceOutput,
              outputs: [buildOutput],
            }),
          ],
        },
        {
          stageName: 'Check',
          actions: [
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Lint',
              project: lintProject,
              input: buildOutput,
              runOrder: 1,
            }),
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Test',
              project: testProject,
              input: buildOutput,
              runOrder: 1,
            }),
            new codepipeline_actions.CodeBuildAction({
              actionName: 'SCA_Check',
              project: scaProject,
              input: buildOutput,
              runOrder: 1,
            }),
            new codepipeline_actions.CodeBuildAction({
              actionName: 'SAST_Check',
              project: sastProject,
              input: buildOutput,
              runOrder: 1,
            }),
          ],
        },
        {
          stageName: 'Deploy',
          actions: [
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Deploy_Lambda',
              project: this.createLambdaDeployProject(artifactBucket),
              input: buildOutput,
              runOrder: 1,
            }),
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Deploy_ECS',
              project: this.createECSDeployProject(artifactBucket),
              input: buildOutput,
              runOrder: 1,
            }),
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Deploy_EC2',
              project: this.createEC2DeployProject(artifactBucket),
              input: buildOutput,
              runOrder: 1,
            }),
          ],
        },
      ],
    });
  }

  private createCacheProject(artifactBucket: s3.Bucket): codebuild.Project {
    return new codebuild.Project(this, 'CacheProject', {
      projectName: 'cicd-comparison-cache',
      source: codebuild.Source.codeCommit({
        repository: codebuild.Repository.fromCodeCommitRepository(/* ... */),
      }),
      environment: {
        buildImage: codebuild.LinuxBuildImage.STANDARD_7_0,
        computeType: codebuild.ComputeType.SMALL,
      },
      buildSpec: codebuild.BuildSpec.fromSourceFilename('cicd/buildspecs/cache.yml'),
      cache: codebuild.Cache.local(codebuild.LocalCacheMode.DOCKER_LAYER, codebuild.LocalCacheMode.CUSTOM),
    });
  }

  // 他のプロジェクト作成メソッドも同様に実装...
}
```

### 手動でのパイプライン作成

#### 1. パイプラインの作成

```bash
aws codepipeline create-pipeline --cli-input-json file://pipeline.json
```

`pipeline.json`：

```json
{
  "pipeline": {
    "name": "cicd-comparison-pipeline",
    "roleArn": "arn:aws:iam::123456789012:role/CodePipelineServiceRole",
    "artifactStore": {
      "type": "S3",
      "location": "cicd-comparison-artifacts-123456789012"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "ThirdParty",
              "provider": "GitHub",
              "version": "1"
            },
            "configuration": {
              "Owner": "your-username",
              "Repo": "your-repo",
              "Branch": "main",
              "OAuthToken": "{{resolve:secretsmanager:github-token}}"
            },
            "outputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Check",
        "actions": [
          {
            "name": "Lint",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "cicd-comparison-lint"
            },
            "inputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ],
            "runOrder": 1
          }
        ]
      }
    ]
  }
}
```

## 🏗️ CodeBuild設定

### キャッシュ作成プロジェクト

`cicd/buildspecs/cache.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Creating cache for dependencies..."
      - uv sync --dev
      - echo "Cache creation completed"

  post_build:
    commands:
      - echo "Cache artifacts prepared"

artifacts:
  files:
    - '**/*'

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

### 静的解析プロジェクト

`cicd/buildspecs/lint.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Running static analysis..."
      - uv run ruff check .
      - uv run black --check .

  post_build:
    commands:
      - echo "Static analysis completed successfully"

reports:
  lint_report:
    files:
      - 'lint-results.xml'
    file-format: 'JUNITXML'

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

### ユニットテストプロジェクト

`cicd/buildspecs/test.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Running unit tests..."
      - uv run pytest --cov=modules/api --cov-report=xml --cov-report=html --junitxml=test-results.xml

  post_build:
    commands:
      - echo "Unit tests completed successfully"

reports:
  test_report:
    files:
      - 'test-results.xml'
    file-format: 'JUNITXML'
  coverage_report:
    files:
      - 'coverage.xml'
    file-format: 'COBERTURAXML'

artifacts:
  files:
    - 'htmlcov/**/*'
  name: coverage-report

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

### SCAチェックプロジェクト

`cicd/buildspecs/sca.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Running SCA scan with CodeGuru Security..."
      - SCAN_NAME="${SERVICE_NAME}-${STAGE_NAME}-sca-$(date +%s)"
      - echo "Scan name: $SCAN_NAME"
      - zip -r /tmp/source-code.zip . -x "*.git*" "node_modules/*" "*.pyc" "__pycache__/*" ".venv/*"
      - bash ./cicd/scripts/run_codeguru_security.sh $SCAN_NAME /tmp/source-code.zip $AWS_DEFAULT_REGION

  post_build:
    commands:
      - CRITICAL_COUNT=$(jq '[.findings[] | select(.severity == "Critical")] | length' $SCAN_NAME.json)
      - HIGH_COUNT=$(jq '[.findings[] | select(.severity == "High")] | length' $SCAN_NAME.json)
      - MEDIUM_COUNT=$(jq '[.findings[] | select(.severity == "Medium")] | length' $SCAN_NAME.json)
      - LOW_COUNT=$(jq '[.findings[] | select(.severity == "Low")] | length' $SCAN_NAME.json)
      - |
        echo "--------- SCA Vulnerability Analysis --------"
        echo "Critical severity vulnerabilities found:" $CRITICAL_COUNT
        echo "High severity vulnerabilities found:" $HIGH_COUNT
        echo "Medium severity vulnerabilities found:" $MEDIUM_COUNT
        echo "Low severity vulnerabilities found:" $LOW_COUNT
        echo "--------------------------------------------"
      - |
        if [ "$CRITICAL_COUNT" -gt 0 ]; then
          echo "ERROR: Found $CRITICAL_COUNT critical vulnerabilities"
          exit 1
        fi

artifacts:
  files:
    - $SCAN_NAME.json
  name: sca-report

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

### SASTチェックプロジェクト

`cicd/buildspecs/sast.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Running SAST scan with Amazon Inspector..."
      - SCAN_NAME="${SERVICE_NAME}-${STAGE_NAME}-sast-$(date +%s)"
      - echo "Scan name: $SCAN_NAME"
      - zip -r /tmp/source-code.zip . -x "*.git*" "node_modules/*" "*.pyc" "__pycache__/*" ".venv/*"
      - bash ./cicd/buildspecs/run_inspector_scan.sh $SCAN_NAME /tmp/source-code.zip $AWS_DEFAULT_REGION

  post_build:
    commands:
      - CRITICAL_COUNT=$(jq '[.findings[] | select(.severity == "CRITICAL")] | length' $SCAN_NAME.json)
      - HIGH_COUNT=$(jq '[.findings[] | select(.severity == "HIGH")] | length' $SCAN_NAME.json)
      - MEDIUM_COUNT=$(jq '[.findings[] | select(.severity == "MEDIUM")] | length' $SCAN_NAME.json)
      - LOW_COUNT=$(jq '[.findings[] | select(.severity == "LOW")] | length' $SCAN_NAME.json)
      - |
        echo "--------- SAST Vulnerability Analysis --------"
        echo "Critical severity vulnerabilities found:" $CRITICAL_COUNT
        echo "High severity vulnerabilities found:" $HIGH_COUNT
        echo "Medium severity vulnerabilities found:" $MEDIUM_COUNT
        echo "Low severity vulnerabilities found:" $LOW_COUNT
        echo "---------------------------------------------"
      - |
        if [ "$CRITICAL_COUNT" -gt 0 ]; then
          echo "ERROR: Found $CRITICAL_COUNT critical vulnerabilities"
          exit 1
        fi

artifacts:
  files:
    - $SCAN_NAME.json
  name: sast-report

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

## 🚀 デプロイ設定

### Lambda デプロイ

`cicd/buildspecs/deploy_lambda.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh
      - pip install aws-sam-cli

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Building SAM application..."
      - sam build
      - echo "Deploying to Lambda..."
      - sam deploy --no-confirm-changeset --no-fail-on-empty-changeset --stack-name cicd-comparison-lambda-${STAGE_NAME}

  post_build:
    commands:
      - echo "Lambda deployment completed successfully"
      - aws cloudformation describe-stacks --stack-name cicd-comparison-lambda-${STAGE_NAME} --query 'Stacks[0].Outputs'

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

### ECS デプロイ

`cicd/buildspecs/deploy-ecs.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $IMAGE_REPO_NAME .
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:latest
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG

  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"cicd-comparison-container","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imageDetail.json
      - echo "ECS deployment preparation completed"

artifacts:
  files:
    - imageDetail.json
    - taskdef.json
    - appspec.yml

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

### EC2 デプロイ

`cicd/buildspecs/deploy_ec2.yml`：

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash cicd/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash cicd/buildspecs/common_pre_build.sh

  build:
    commands:
      - . cicd/buildspecs/common_env.sh
      - echo "Preparing EC2 deployment package..."
      - zip -r deployment.zip . -x "*.git*" ".cache/*" ".venv/*" "node_modules/*" "*.zip"
      - echo "Uploading deployment package to S3..."
      - aws s3 cp deployment.zip s3://$DEPLOYMENT_BUCKET/deployments/$CODEBUILD_BUILD_NUMBER.zip

  post_build:
    commands:
      - echo "Creating CodeDeploy deployment..."
      - |
        aws deploy create-deployment \
          --application-name $CODEDEPLOY_APPLICATION \
          --deployment-group-name $CODEDEPLOY_DEPLOYMENT_GROUP \
          --deployment-config-name CodeDeployDefault.EC2AllAtOnceBlueGreen \
          --s3-location bucket=$DEPLOYMENT_BUCKET,key=deployments/$CODEBUILD_BUILD_NUMBER.zip,bundleType=zip
      - echo "EC2 deployment initiated successfully"

cache:
  key: cache-key-$(codebuild-hash-files .tool-versions)-$$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

## 📊 監視とログ

### CloudWatch監視

#### パイプライン監視

```bash
# パイプライン実行状況の確認
aws codepipeline get-pipeline-state --name cicd-comparison-pipeline

# パイプライン実行履歴
aws codepipeline list-pipeline-executions --pipeline-name cicd-comparison-pipeline
```

#### CodeBuild監視

```bash
# ビルド実行状況の確認
aws codebuild list-builds-for-project --project-name cicd-comparison-lint

# ビルドログの確認
aws logs get-log-events --log-group-name /aws/codebuild/cicd-comparison-lint --log-stream-name <stream-name>
```

### CloudWatch Dashboardの作成

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/CodePipeline", "PipelineExecutionSuccess", "PipelineName", "cicd-comparison-pipeline"],
          [".", "PipelineExecutionFailure", ".", "."]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "ap-northeast-1",
        "title": "Pipeline Execution Status"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/CodeBuild", "Duration", "ProjectName", "cicd-comparison-lint"],
          [".", ".", ".", "cicd-comparison-test"],
          [".", ".", ".", "cicd-comparison-sca"],
          [".", ".", ".", "cicd-comparison-sast"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ap-northeast-1",
        "title": "Build Duration"
      }
    }
  ]
}
```

### アラート設定

```bash
# パイプライン失敗アラート
aws cloudwatch put-metric-alarm \
  --alarm-name "CodePipeline-Failure" \
  --alarm-description "Alert when CodePipeline fails" \
  --metric-name PipelineExecutionFailure \
  --namespace AWS/CodePipeline \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=PipelineName,Value=cicd-comparison-pipeline \
  --evaluation-periods 1
```

## 🔧 トラブルシューティング

### よくある問題

#### 1. IAM権限エラー

**エラー**: `AccessDenied: User is not authorized to perform`

**解決策**:

```bash
# IAMロールの権限確認
aws iam get-role-policy --role-name CodePipelineServiceRole --policy-name CodePipelineServiceRolePolicy

# 必要な権限の追加
aws iam put-role-policy --role-name CodePipelineServiceRole --policy-name AdditionalPermissions --policy-document file://additional-permissions.json
```

#### 2. S3アーティファクトエラー

**エラー**: `The bucket does not allow ACLs`

**解決策**:

```bash
# S3バケットのACL設定確認
aws s3api get-bucket-acl --bucket codepipeline-artifacts-123456789012

# バケットポリシーの更新
aws s3api put-bucket-policy --bucket codepipeline-artifacts-123456789012 --policy file://bucket-policy.json
```

#### 3. CodeBuildタイムアウト

**エラー**: `Build timed out`

**解決策**:

```yaml
# buildspec.ymlでタイムアウト設定
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.13
    commands:
      - echo "Extending timeout..."
# CodeBuildプロジェクトでタイムアウトを延長
```

#### 4. Docker権限エラー

**エラー**: `Cannot connect to the Docker daemon`

**解決策**:

```yaml
# buildspec.ymlで特権モードを有効化
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
```

### デバッグ方法

#### 1. CloudWatch Logsでのデバッグ

```bash
# ログストリームの確認
aws logs describe-log-streams --log-group-name /aws/codebuild/cicd-comparison-lint

# ログの取得
aws logs get-log-events --log-group-name /aws/codebuild/cicd-comparison-lint --log-stream-name <stream-name>
```

#### 2. CodeBuildローカル実行

```bash
# CodeBuildエージェントのダウンロード
git clone https://github.com/aws/aws-codebuild-docker-images.git
cd aws-codebuild-docker-images/ubuntu/standard/7.0

# ローカルでのビルド実行
docker build -t aws/codebuild/standard:7.0 .
docker run -it --privileged -v /var/run/docker.sock:/var/run/docker.sock aws/codebuild/standard:7.0
```

#### 3. パイプライン実行の詳細確認

```bash
# 実行詳細の取得
aws codepipeline get-pipeline-execution --pipeline-name cicd-comparison-pipeline --pipeline-execution-id <execution-id>

# アクション実行詳細
aws codepipeline list-action-executions --pipeline-name cicd-comparison-pipeline
```

### パフォーマンス最適化

#### 1. キャッシュの最適化

```yaml
cache:
  key: ccache-key-$(codebuild-hash-files uv.lock)-$(codebuild-hash-files package-lock.json)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - 'node_modules/**/*'
    - '.venv/**/*'
```

#### 2. 並列実行の最適化

```typescript
// CDKでの並列実行設定
new codepipeline_actions.CodeBuildAction({
  actionName: 'Parallel_Action_1',
  project: project1,
  input: sourceOutput,
  runOrder: 1,
}),
new codepipeline_actions.CodeBuildAction({
  actionName: 'Parallel_Action_2',
  project: project2,
  input: sourceOutput,
  runOrder: 1, // 同じrunOrderで並列実行
}),
```

#### 3. リソース最適化

```typescript
// CodeBuildプロジェクトのリソース設定
environment: {
  buildImage: codebuild.LinuxBuildImage.STANDARD_7_0,
  computeType: codebuild.ComputeType.LARGE, // 必要に応じてサイズ調整
  privileged: true, // Dockerビルドに必要
},
```

## 📚 参考資料

- [AWS CodePipeline Documentation](https://docs.aws.amazon.com/cicd/)
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [CodeGuru Security Documentation](https://docs.aws.amazon.com/codeguru/latest/security-ug/)
- [Amazon Inspector Documentation](https://docs.aws.amazon.com/inspector/)
